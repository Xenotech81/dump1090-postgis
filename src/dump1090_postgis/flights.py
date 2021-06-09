import datetime
import logging
import string

from sqlalchemy.orm.session import Session

from dump1090_postgis import models
from dump1090_postgis import adsb_parser
from dump1090_postgis.airports import nte_airport

log = logging.getLogger(__name__)


class CurrentFlights:
    """Pool of currently observed flights."""

    # Maximum age in seconds since last seen of a flight before it gets deleted from the pool
    MAX_AGE = 300
    # Commit to Postgres every X seconds
    DB_COMMIT_PERIOD = 1

    def __init__(self, session: Session, adsb_filter: adsb_parser.AdsbMessageFilter = None):
        """
        Constructor of the flight pool.

        :param session: A DB connection instance.
        :type session: sqlalchemy.orm.session.Session
        :param adsb_filter: The filter object which will decide if a flight will be tracked or not
        :type adsb_filter: adsb_parser.AdsbMessageFilter
        """

        assert isinstance(session, Session)
        #assert isinstance(adsb_filter, adsb_parser.AdsbMessageFilter)

        # Key-value pairs of fight hexident and models.Flight instances
        self._flights = {}
        self._adsb_filter = adsb_filter
        self.__session = session
        self.__last_session_commit = datetime.datetime.now(datetime.timezone.utc)

        self._landing_and_takeoff_manager = LandingAndTakeoffManager(session)

    def __getitem__(self, hexident: string) -> models.Flight:
        try:
            return self._flights[hexident]
        except KeyError:
            log.error("Trying to get Flight {} which does not exist in current flights pool.".format(hexident))
            return None

    def __setitem__(self, key, value):
        assert isinstance(value, models.Flight)
        self._flights[key] = value

    def __iter__(self):
        for flight in self._flights.values():
            yield flight

    def __len__(self):
        return len(self._flights.values())

    def update(self, adsb_message: adsb_parser.AdsbMessage):
        """
        Updates the flights pool from a ADSb message object and commits to Postgres.

        Two cases are distinguished:

        CASE A:
        If hexident is already known, the according Flight instance will get updated with the message contents and
        queued for commit to DB.

        CASE B:
        If hexident is unknown, it will be added to the pool in one of the cases:
            1. Transmission type equals 2: Aircraft is on ground, only lat/lon is transmitted. No altitude filter
            applicable.
            2. Transmission type equals 3 (=altitude is included in the message) AND altitude filter returns True.

        After adding the new hexident to the pool, the flight is registered on the 'landing_and_takeoff_manager' which
        recognizes landing and takeoff events. Then, the Flight instance is updated with the ADSB message content, added
        to the SQL session and the session is committed to the DB immediately.

        In both cases, the flight pool is 'pruned' = aged flights are removed.

        :param adsb_message: Instance of adsb_parser.AdsbMessage
        """

        if adsb_message.hexident in self._flights.keys():
            self[adsb_message.hexident].update(adsb_message)
            log.debug("Flight {} updated".format(adsb_message.hexident))

            self._commit_flights(period=self.DB_COMMIT_PERIOD)
            self.prune()

        elif adsb_message.transmission_type == 2 or (adsb_message.transmission_type == 3 and self._adsb_filter.altitude(
                adsb_message)):
            log.info("New flight spotted: {} Adding to current pool...".format(adsb_message.hexident))

            self[adsb_message.hexident] = models.Flight(adsb_message.hexident)

            log.info(self)  # Print pool contents for info

            # Register the manager's callback methods as subscribers to this Flight instance
            self[adsb_message.hexident].register_on_landing(self._landing_and_takeoff_manager.on_landing_callback)
            self[adsb_message.hexident].register_on_takeoff(self._landing_and_takeoff_manager.on_takeoff_callback)

            self[adsb_message.hexident] = self[adsb_message.hexident].update(adsb_message)

            self.__session.add(self._flights[adsb_message.hexident])

            self._commit_flights()  # Immediate commit
            self.prune()

    def prune(self):
        """Remove all flights from the pool which are older than MAX_AGE."""
        _aged__flights = list(filter(lambda f: f.age > datetime.timedelta(seconds=self.MAX_AGE),
                                     self._flights.values()))
        for f in _aged__flights:
            log.info("Removing aged flight {} from current flight pool.".format(f.hexident))
            del self._flights[f.hexident]

    def _commit_flights(self, period: int = None):
        """
        Commits all currently observed flights to DB.

        If period==None, the commit is performed immediately.
        If an integer is provided as a commit period (in seconds), the commit is delayed by this amount relative to
        the time value saved in the instance attribute __last_session_commit.
        """
        _now = datetime.datetime.now(datetime.timezone.utc)

        if period is None or _now > self.__last_session_commit + datetime.timedelta(seconds=self.DB_COMMIT_PERIOD):
            self.__session.commit()
            self.__last_session_commit = _now

    def __repr__(self):
        return "Current flight pool contains {} fights: {}".format(len(self), ', '.join(self.hexidents()))

    def hexidents(self):
        return self._flights.keys()


class LandingAndTakeoffManager:
    """Class providing callback methods which add Landing or Takeoff instances to SQL session.

    Provide these callbacks as argument to models.Flight.register_on_landing().
    """
    _airports = [nte_airport]

    def __init__(self, session):
        """Construct by providing the current SQL session.

        :param session: A DB connection instance.
        :type session: sqlalchemy.orm.session.Session
        """
        self.__session = session

    def _callback(self, position: models.Position, flight: models.Flight, event_type):
        """Adds Landing or Takeoff instance to SQL session if touchdown or takoff event was identified.

        If the airports.Airport.get_runway() method identifies a touchdown or takeoff from the flight's last
        position and interpolated track, then this callback function will add a models.Landings or models.Takeoffs
        instance to the SQL session.

        :param position: Position for which the attribute models.Position.onground just switched from False to True (=landing) or inverse (takeoff)
        :type position:   models.Position
        :param flight: Flight instance to which the position belongs.
        :type flight: models.Flight
        :param event_type: Instance of Landing or Takeoff event
        :type event_type: models.Landings or models.Takeoffs
        """

        assert isinstance(position, models.Position)
        assert isinstance(flight, models.Flight)
        assert issubclass(event_type, (models.Landings, models.Takeoffs))

        for airport in LandingAndTakeoffManager._airports:
            runway = airport.get_runway(position.point, flight.interpolated_track)
            if runway:
                self.__session.add(event_type(flight, position, runway))
                log.info("{}: Flight {} just {} on runway {}!".format(position.time,
                                                                      flight.hexident,
                                                                  'landed' if issubclass(event_type, models.Landings)
                                                                      else
                                                                  'took off',
                                                                  runway.name)
                         )
                self.__session.commit()
                break

    def on_landing_callback(self, position, flight):
        """Adds a models.Landings instance to SQL session if the landing can be attributed to a runway."""
        self._callback(position, flight, models.Landings)

    def on_takeoff_callback(self, position, flight):
        """Adds a models.Takeoff instance to SQL session if the takeoff can be attributed to a runway."""
        self._callback(position, flight, models.Takeoffs)


if __name__ == '__main__':
    pass
