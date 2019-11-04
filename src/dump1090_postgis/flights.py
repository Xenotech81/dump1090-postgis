import logging
import string

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from config import DB_URL
import models
import adsb_parser

log = logging.getLogger(__name__)

engine = create_engine(DB_URL, echo=True)
Session = sessionmaker(bind=engine)

session = Session()

class CurrentFlights(object):
    """
    Pool of currently observed flights.

    todo: Poll last_seen of flights and move old ones to PastFlights
    """

    def __init__(self, adsb_filter: adsb_parser.AdsbMessageFilter = None):
        # Key-value pairs of fight hexident and models.Flight instances
        self._flights = {}
        self._adsb_filter = adsb_filter

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
        for flight in self._flights:
            yield flight

    def __len__(self):
        return len(self._flights)

    def update(self, adsb_message: adsb_parser.AdsbMessage):
        """
        Updates the flight pool from a ADSb message object.
        :param adsb_message: Intance of adsb_parser.AdsbMessage
        :param adsb_filter: Configured AdsbMessageFilter instance
        :return: None
        """

        if self._adsb_filter is not None:
            if not self._adsb_filter.filter(adsb_message):
                log.debug("Message filtered out by ADSb filter.")
                return

        try:
            self._flights[adsb_message.hexident].update(adsb_message)
            log.debug("Flight {} updated".format(adsb_message.hexident))
        except KeyError:
            log.debug("Adding new flight '{}' to current pool".format(adsb_message.hexident))
            self._flights[adsb_message.hexident] = models.Flight(adsb_message.hexident).update(adsb_message)

        #session.merge(self._flights[adsb_message.hexident])

    def _commit_flights(self):
        """
        Commits all currently observed flights to DB.
        :return:
        """
        session.commit()


    def __repr__(self):
        return "Current flight pool contains {} fights: \n{}".format(len(self), '\n'.join(self.hexidents()))

    def hexidents(self):
        return self._flights.keys()


def create_flight_table():
    models.Flight.__table__.create(engine)

def delete_flight_table():
    models.Flight.__table__.drop(engine)


if __name__ == '__main__':
    import time

    logging.basicConfig(level=logging.INFO)

    # Pool of currently visible flights
    current_flights = CurrentFlights(adsb_filter=adsb_parser.AdsbMessageFilter(below=10000, above=0))

    #message_source = adsb_parser.Dump1090Socket()
    message_source = adsb_parser.FileSource('adsb_message_stream.txt')

    i = 0
    start = time.time()
    for msg in adsb_parser.AdsbMessage(message_source):
        current_flights.update(msg)
        i += 1
    duration = time.time() - start
    log.info("{} messages processed in {}sec".format(i, duration))

    log.info(current_flights)
    log.info(list(current_flights['396444'].flight_path()))
