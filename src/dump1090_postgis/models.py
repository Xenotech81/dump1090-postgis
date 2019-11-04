import datetime
import enum
import logging
import string
import time

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, TIMESTAMP, BOOLEAN
from geoalchemy2 import Geometry
# https://geoalchemy-2.readthedocs.io/en/latest/shape.html
from geoalchemy2.shape import from_shape
from shapely.geometry import LineString

import adsb_parser

log = logging.getLogger(__name__)

Base = declarative_base()

# Spatial Reference Id of the flight path xy coordinates
SRID = 4326
# Unit of the flight altitude to save in the database ['m', 'ft']
ALT_UNIT = 'm'


def feet2m(ft):
    return 0.3048 * ft


class Intention(enum.Enum):
    """
    Enumerator for flight intention: departure, arrival or passing by (flyby).
    """
    flyby = 'flyby'
    departure = 'departure'
    arrival = 'arrival'


class Flight(Base):
    __tablename__ = 'flights'
    id = Column(Integer, primary_key=True)
    hexident = Column(String(6), nullable=False)
    callsign = Column(String(7))
    # gen_date_time timestamp of the first ADSb message of this hexiden processed
    first_seen = Column(TIMESTAMP, nullable=False)
    # gen_date_time timestamp of (any) last ADSb message of this hexident
    last_seen = Column(TIMESTAMP)
    groundtrack = Geometry('LINESTRING', srid=SRID)
    onground = Column(BOOLEAN)
    # arrival, departure, flyby
    intention = Column(String(9))

    # Altitude [m] of airport (will be used to set altitude for MSG type 2)
    # Note: NTE is at 90ft ASL
    GND_ALTITUDE = 0

    def __init__(self, hexident: string):
        self.hexident = hexident
        self.verticalrate = None
        self.squawk = None
        self.__groundtrack = []
        self.__altitudes = []  # List of altitudes [m]
        self.__times = []
        self._transmission_type_count = dict.fromkeys(range(1, 9, 1), 0)

    def __str__(self):
        return "Flight {hexident}: last seen: {last_seen}".format(**self.__dict__)

    def _add_position(self, x: float, y: float, z: float, t: datetime.datetime):
        """
        Adds x,y coordinates and timestamp of a single flight path position.
        :param x: x coordinate (longitude)
        :param y: y coordinate (latitude)
        :param z: height above ground [m]
        :param t: timestamp (todo: DateTime is still passed, change this)
        :return:
        """
        self.__groundtrack.append([x, y])
        self.__altitudes.append(feet2m(z))
        self.__times.append(t)

        # A LineString must consist of at least 2 point to form a line segment
        if len(self.__groundtrack) <= 1:
            pass
        else:
            self.groundtrack = from_shape(LineString(self.__groundtrack), srid=SRID)

    def flight_path(self):
        """
        Returns a iterator over tuples of timestamp and xyz coordinates.
        :return: Iterator of (time, (x, y, z))
        """
        return ((t, xyz[0][0], xyz[0][1], xyz[1]) for t, xyz in
                zip(self.__times, zip(self.__groundtrack, self.__altitudes)))

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

        # Update only if msg includes coordinates
        # ATTENTION: x: longitude (easting), y: latitude (northing)
        if adsb.transmission_type == 3:
            self._add_position(adsb.longitude, adsb.latitude, adsb.altitude, adsb.gen_date_time)
        if adsb.transmission_type == 2:
            self._add_position(adsb.longitude, adsb.latitude, self.GND_ALTITUDE, adsb.gen_date_time)
        return self


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)

    message_source = adsb_parser.FileSource('adsb_message_stream.txt')
    flight = Flight('405D0F')

    i = 0
    start = time.time()
    for msg in adsb_parser.AdsbMessage(message_source):
        flight.update(msg)
        i += 1

    duration = time.time() - start
    log.info("{} operations in {}sec".format(i, duration))

    log.info(list(flight.flight_path()))
