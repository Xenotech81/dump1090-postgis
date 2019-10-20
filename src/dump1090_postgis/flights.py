import logging
import string

from models import Flight
import adsb_parser

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)


class CurrentFlights(object):
    """
    Pool of currently observed flights.

    todo \
    - Filter functions (<10000 feet, distance, ...)
    - forward message to all flights (better: subscriber!)
    - Poll last_seen of flights and move old ones to PastFlights
    """

    def __init__(self):
        # Key-value pairs of fight hexident and models.Flight instances
        self._flights = {}

    def update(self, adsb_message: adsb_parser.AdsbMessage):
        """
        Updates the flight pool from a ADSb message object.
        :param adsb_message: Intance of adsb_parser.AdsbMessage
        :return: None
        """
        try:
            self._flights[adsb_message.hexident].update(adsb_message)
            log.debug("Flight {} updated".format(adsb_message.hexident))
        except KeyError:
            log.debug("Adding new flight '{}' to current pool".format(adsb_message.hexident))
            self._flights[adsb_message.hexident] = Flight(adsb_message.hexident).update(adsb_message)

    def __repr__(self):
        return "Current flight pool contains {} fights: \n{}".format(len(self._flights), '\n'.join(self.hexidents()))

    def hexidents(self):
        return self._flights.keys()


if __name__ == '__main__':

    # Pool of currently visible flights
    current_flights = CurrentFlights()

    message_source = adsb_parser.FileSource('messages_long.txt')
    for msg in adsb_parser.AdsbMessage(message_source):
        current_flights.update(msg)

    log.info(current_flights)
    log.info(current_flights._flights['396444']._transmission_type_count)
