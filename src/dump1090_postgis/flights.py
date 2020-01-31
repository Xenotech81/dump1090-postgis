import datetime
import logging
import os
import string

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy_utils import database_exists  # create_database, drop_database
from sqlalchemy.exc import DBAPIError  # SQLAlchemyError

from config import DB_URL
from dump1090_postgis import models
from dump1090_postgis import adsb_parser

log = logging.getLogger(__name__)

engine = create_engine(DB_URL, echo=False)
Session = sessionmaker(bind=engine)

session = Session()


class CurrentFlights(object):
    """
    Pool of currently observed flights.

    todo: Poll last_seen of flights and move old ones to PastFlights
    """

    # Maximum age in seconds since last seen of a flight before it gets deleted from the pool
    MAX_AGE = 300
    # Commit to Postgres every X seconds
    DB_COMMIT_PERIOD = 1

    def __init__(self, adsb_filter: adsb_parser.AdsbMessageFilter = None):
        # Key-value pairs of fight hexident and models.Flight instances
        self._flights = {}
        self._adsb_filter = adsb_filter

        self.__last_session_commit = datetime.datetime.utcnow()

    def __getitem__(self, hexident: string) -> models.Flight:
        try:
            return self._flights[hexident]
        except KeyError:
            log.error("Cannot find flight {} in current flights pool. Not on the radar...".format(hexident))
            return None

    def __setitem__(self, key, value):
        assert isinstance(value, models.Flight)
        self._flights[key] = value

    def __iter__(self):
        for flight in self._flights.values():
            yield flight

    def __len__(self):
        return len(self._flights)

    def update(self, adsb_message: adsb_parser.AdsbMessage):
        """
        Updates the flight pool from a ADSb message object and commits to Postgres.

        If hexident is already known, the according Flight instance will get updated with the message contents and
        merged into the current SQL session, if it passes all filters (e.g. altitude).

        If hexident is unknown, it will be added to the pool in one of the cases:
            1. Transmission type is 2: Aircraft is on ground, only lat/lon is transmitted. No altitude filter
            applicable.
            2. Transmission type is 3 (=altitude is included in the message) AND altitude filter returns True
        After adding the new hexident to the pool, the Flight instance is updated and added to the SQL session.
        Finally, the session is commited to DB.

        In any case, the flight pool is 'pruned' = aged flights are removed

        :param adsb_message: Instance of adsb_parser.AdsbMessage
        """

        if adsb_message.hexident in self._flights and self._adsb_filter.altitude(adsb_message):
            self._flights[adsb_message.hexident].update(adsb_message)
            log.debug("Flight {} updated".format(adsb_message.hexident))
            session.merge(self._flights[adsb_message.hexident])

            self._commit_flights(period=self.DB_COMMIT_PERIOD)

        elif adsb_message.transmission_type == 2 or (adsb_message.transmission_type == 3 and self._adsb_filter.altitude(
                adsb_message)):
            log.info("New flight spotted: {} Adding to current pool...".format(adsb_message.hexident))
            new_flight = models.Flight(adsb_message.hexident)
            self._flights[adsb_message.hexident] = new_flight.update(adsb_message)

            session.add(self._flights[adsb_message.hexident])
            self._commit_flights()

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
        _now = datetime.datetime.utcnow()

        if period is None or _now > self.__last_session_commit + datetime.timedelta(seconds=self.DB_COMMIT_PERIOD):
            session.commit()
            self.__last_session_commit = _now

    def __repr__(self):
        return "Current flight pool contains {} fights: \n{}".format(len(self), '\n'.join(self.hexidents()))

    def hexidents(self):
        return self._flights.keys()


def create_flight_table():
    """
    Recreates flights table in DB.
    L(https://docs.sqlalchemy.org/en/13/core/exceptions.html)
    """
    if database_exists(DB_URL):
        try:
            models.Flight.__table__.create(engine)
            models.Position.__table__.create(engine)
        except DBAPIError as err:
            log.warning("Cannot create table: %s", str(err))
    else:
        raise RuntimeError("DB {} does not exist".format(DB_URL))


def delete_flight_table():
    """
    Deletes flights table in DB.
    L(https://docs.sqlalchemy.org/en/13/core/exceptions.html)
    """
    if database_exists(DB_URL):
        try:
            models.Position.__table__.drop(engine)
            models.Flight.__table__.drop(engine)
        except DBAPIError as err:
            log.warning("Cannot delete table: %s", str(err))
    else:
        raise RuntimeError("DB {} does not exist".format(DB_URL))


if __name__ == '__main__':
    pass
