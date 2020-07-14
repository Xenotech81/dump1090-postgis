import datetime
import enum
import logging
import string
import time

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import types, Column, Integer, Float, String, TIMESTAMP, BOOLEAN, ForeignKey, BigInteger, Enum
from sqlalchemy.orm import relationship, backref
from geoalchemy2 import Geometry
# https://geoalchemy-2.readthedocs.io/en/latest/shape.html
from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import Point
from shapely import speedups

from dbmanager import session
from dump1090_postgis import adsb_parser
from dump1090_postgis.airports import Runway
from dump1090_postgis.shared import feet2m, interpolate_track


log = logging.getLogger(__name__)

speedups.enable()

Base = declarative_base()

# Spatial Reference Id of the flight path xy coordinates
SRID = 4326
# Unit of the flight altitude to save in the database ['m', 'ft']
ALT_UNIT = 'm'
# Altitude [m] AGL for 'onground' flight condition (will be used to set altitude for MSG type 2)
# Note: NTE is at 90ft ASL
GND_ALTITUDE = 0


class Intention(enum.Enum):
    """
    Enumerator for flight intention: departure, arrival or passing by (enroute).

    - unknown: Every new Flight is instantiated with this intention
    - departure: If first recorded position was or is *onground*
    - arrival: Flight is decreasing in altitude
    - enroute: If none of the other intention states are fulfilled
    """
    enroute = 'enroute'
    departure = 'departure'
    arrival = 'arrival'
    unknown = 'unknown'


class Position(Base):
    __tablename__ = 'positions'
    id = Column(BigInteger, primary_key=True)
    flight_id = Column(Integer, ForeignKey('flights.id', ondelete='CASCADE'))
    time = Column(TIMESTAMP, nullable=False)
    coordinates = Column(Geometry('POINTZ', srid=SRID, dimension=3))
    verticalrate = Column(Integer)
    track = Column(Integer)
    onground = Column(BOOLEAN, default=False)

    def __str__(self):
        return "Position {id} of flight {flight_id} at {time}: {coordinates} (onground={onground})".format(
            id=self.id,
            flight_id = self.flight_id,
            time = self.time,
            coordinates = to_shape(self.coordinates).coords[:],
            onground = self.onground
            )

    @property
    def lon(self):
        """Longitude"""
        return to_shape(self.coordinates).coords[:][0][0]

    @property
    def lat(self):
        """Latitude"""
        return to_shape(self.coordinates).coords[:][0][1]

    @property
    def alt(self):
        """Altitude [m]"""
        return to_shape(self.coordinates).coords[:][0][2]

    @property
    def point(self):
        return to_shape(self.coordinates)


class Flight(Base):
    __tablename__ = 'flights'
    id = Column(Integer, primary_key=True)
    hexident = Column(String(6), nullable=False)
    callsign = Column(String(7))
    # gen_date_time timestamp of the first ADSb message of this hexiden processed
    first_seen = Column(types.DateTime(timezone=True), nullable=False)
    # gen_date_time timestamp of (any) last ADSb message of this hexident
    last_seen = Column(types.DateTime(timezone=True))
    # https://gis.stackexchange.com/questions/4467/how-to-handle-time-in-gis
    # flightpath = Column(Geometry('LINESTRINGZ', srid=SRID, dimension=3))
    intention = Column(Enum(Intention), default=Intention.unknown)

    #https://stackoverflow.com/questions/5033547/sqlalchemy-cascade-delete
    positions: Position = relationship('Position',
                                       backref=backref('flight', lazy=True),
                                       passive_deletes=True,
                                       order_by="asc(Position.time)")

    def __init__(self, hexident: string):
        self.hexident = hexident
        self.squawk = None
        self.__flightpath = []
        self.__times = []
        self._transmission_type_count = dict.fromkeys(range(1, 9, 1), 0)

        self._on_landing_subscribers = []
        self._on_takeoff_subscribers = []

        self._ground_change_detected = False

    def __str__(self):
        return "Flight {hexident}: last seen: {last_seen}".format(**self.__dict__)

    @property
    def age(self) -> datetime.timedelta:
        """
        Computes the age in seconds since last seen.
        :return: Age in seconds since last seen
        """
        return datetime.datetime.now(datetime.timezone.utc) - self.last_seen

    @property
    def interpolated_track(self):
        """Compute flight heading from last known 2 positions."""
        if len(self.positions) >= 2:
            return interpolate_track(self.positions[-2:])
        else:
            return None

    def update(self, adsb: adsb_parser.AdsbMessage):
        """
        Updates the instance attributes with values from an ADSb message object and returns.

        MSG types and contained info:
        - 1: callsign & onground
        - 2: speed & latitude & longitude & onground
        - 3: altitude & latitude & longitude
        - 4: speed & track & verticalrate & onground
        - 5: altitude OR altitude & vertical_rate OR altitude & speed & track
        - 6: (speed & track) (verticalrate) squawk & alert & emergency & spi
        - 7: altitude
        - 8: onground

        :param adsb: Instance of AdsbMessage
        :returns Updated version of self
        """

        # Upon landing MSG type changes from 3 to 2 (no altitude is transmitted after landing)
        MSG_FIELDS = {1: ('callsign', 'onground'),
                      2: ('speed', 'latitude', 'longitude', 'onground'),
                      3: ('altitude', 'latitude', 'longitude', 'onground'),
                      4: ('speed', 'track', 'verticalrate', 'onground'),
                      5: ('altitude', 'verticalrate'),
                      8: ('onground',)
                      }

        if adsb.hexident != self.hexident:
            log.error(
                "Trying to update flight '{}' with ADSb message of flight '{}'".format(self.hexident, adsb.hexident))
            return self

        self._transmission_type_count[adsb.transmission_type] += 1

        if not self.first_seen:
            self.first_seen = adsb.gen_date_time

        # Note: last_seen timestamp gets updated from any MSG type, regardless whether the message content will be used
        # to update the object attributes or not.
        self.last_seen = adsb.gen_date_time

        # Process only message types defined as keys in MSG_FIELDS
        try:
            log.debug("Updating flight {} with MSG type: {}".format(self.hexident, adsb.transmission_type))
            for field in MSG_FIELDS[adsb.transmission_type]:
                setattr(self, field, getattr(adsb, field))
                log.debug("Updating field: {}={}".format(field, getattr(adsb, field)))
        except KeyError:
            log.debug("Skipping updating flight with transmission type {:d}: {}".format(adsb.transmission_type, adsb))

        # Update flight path geometry only if msg includes coordinates
        # ATTENTION: x: longitude (easting), y: latitude (northing)
        if adsb.transmission_type == 3:
            if adsb.longitude is not None and adsb.latitude is not None and adsb.altitude is not None:
                position = Position(time=adsb.gen_date_time,
                                               coordinates=from_shape(
                                                   Point(adsb.longitude, adsb.latitude, feet2m(adsb.altitude)),
                                                   srid=SRID),
                                               onground=adsb.onground)
                self.positions.append(position)
                self.identify_onground_change()
                self.classify_intention()

            else:
                log.debug("Cannot update position as MSG3 did not include lon/lat: {}".format(str(adsb)))
        # First MSG2 of aircraft at terminal does not contain coordinates, only 'onground'
        # Also, the altitude is not included in MSG2, and is being set here to GND_ALTITUDE (0m AGL)
        elif adsb.transmission_type == 2 and adsb.longitude is not None and adsb.latitude is not None:
            self.positions.append(Position(time=adsb.gen_date_time,
                                           coordinates=from_shape(Point(adsb.longitude, adsb.latitude, GND_ALTITUDE),
                                                                  srid=SRID),
                                           onground=adsb.onground)
                                  )
            self.identify_onground_change()
            self.classify_intention()

        return self

    def register_on_landing(self, subscriber):
        """Register an on-landing subscriber."""
        self._on_landing_subscribers.append(subscriber)

    def register_on_takeoff(self, subscriber):
        """Register an on-takeoff subscriber."""
        self._on_takeoff_subscribers.append(subscriber)

    def _broadcast_landing(self, position):
        """Call the callback of landing subscribers."""
        for subscriber in self._on_landing_subscribers:
            subscriber(position, self)

    def _broadcast_takeoff(self, position):
        """Call the callback of takeoff subscribers."""
        for subscriber in self._on_takeoff_subscribers:
            subscriber(position, self)

    def identify_onground_change(self):
        """Identify takeoff or landing event and emit message to subscribers."""

        # Skip all checks if takeoff or landing was already previously detected for this flight to save CPU.
        if self._ground_change_detected:
            return
        # Skip if we are handling the first position
        elif len(self.positions) <= 1:
            return
        else:
            current_position = self.positions[-1]
            previous_position = self.positions[-2]
            if current_position.onground and not previous_position.onground:
                self._ground_change_detected = True
                self._broadcast_landing(current_position)
            elif not current_position.onground and previous_position.onground:
                self._ground_change_detected = True
                self._broadcast_takeoff(current_position)

    def classify_intention(self):
        """Updates the intention (arrival, departure, enroute) guessed from the shape of flight path.

        Any new Flight is instantiated with intention=Intention.unknown.
        Only if the *onground* flag of the first Position instance is True, the flight is classified as *departure*.
        This means that departing flights which recording started only after they took off will be classified as
        *enroute*.
        An *arrival" flight is one which decreased its altitude since *first_seen* moment by ALT_DIFF_FOR_ARRIVAL.
        If none of the above applies, the flight is classified as *enroute*.
        """

        # Altitude difference [meter] between first_ and last_seen time to classify the flight as arrival
        ALT_DIFF_FOR_ARRIVAL = -300

        # Classification as departure flight is quite reliable (first_seen position was 'onground')
        # In this case, the classification can be kept and all other checks skipped
        if self.intention == Intention.departure:
            return self.intention

        if self.positions[0].onground is None:
            self.intention = Intention.unknown
        elif self.positions[0].onground:
            self.intention = Intention.departure
        else:
            if self.positions[-1].alt - self.positions[0].alt < ALT_DIFF_FOR_ARRIVAL:
                self.intention = Intention.arrival
            else:
                self.intention = Intention.enroute

        return self.intention


class Landings(Base):
    __tablename__ = 'landings'
    id = Column(Integer, primary_key=True)
    flight_id = Column(Integer, ForeignKey('flights.id', ondelete='CASCADE'))
    time = Column(TIMESTAMP, nullable=False)
    runway = Column(String(3), nullable=False)

    def __init__(self, flight: Flight, position: Position, runway: Runway):
        self.flight_id = flight.id
        self.time = position.time
        if runway:
            self.runway = runway.name
        else:
            self.runway = 'UNK'

    def __str__(self):
        return "Landing for FlightID {}: Runway {} at {}".format(self.flight_id, self.runway, self.time)


class Takeoffs(Base):
    __tablename__ = 'takeoffs'
    id = Column(Integer, primary_key=True)
    flight_id = Column(Integer, ForeignKey('flights.id', ondelete='CASCADE'))
    time = Column(TIMESTAMP, nullable=False)
    runway = Column(String(3), nullable=False)

    def __init__(self, flight: Flight, position: Position, runway: Runway):
        self.flight_id = flight.id
        self.time = position.time
        if runway:
            self.runway = runway.name
        else:
            self.runway = 'UNK'

    def __str__(self):
        return "Takeoff for FlightID {}: Runway {} at {}".format(self.flight_id, self.runway, self.time)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)

    message_source = adsb_parser.FileSource('../tests/adsb_message_hexident_40757F.txt')
    flight = Flight('40757F')

    i = 0
    start = time.time()
    for msg in adsb_parser.AdsbMessage(message_source):
        flight.update(msg)
        i += 1
    duration = time.time() - start

    log.info("{} operations in {}sec".format(i, duration))
