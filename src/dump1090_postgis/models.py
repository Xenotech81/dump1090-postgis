# from geoalchemy2 import Geometry
import logging
import string
import time

import adsb_parser

log = logging.getLogger(__name__)


class Flight(object):

    def __init__(self, hexident: string):
        self.hexident = hexident
        # Time stamp of last received message
        self.last_seen = None
        # Last position (not necessarily from last message)
        self.position = None
        self.verticalrate = None
        self.squawk = None
        self.onground = True
        self.__flight_track_positions = []
        self.__flight_track_timestamps = []
        self._transmission_type_count = dict.fromkeys(range(1, 9, 1), 0)

    def update(self, adsb: adsb_parser.AdsbMessage):
        """
        Updates the instance attributes with values from an ADSb message object.
        :param adsb: Instance of AdsbMessage
        """
        self._transmission_type_count[adsb.transmission_type] += 1

        self.hexident = adsb.hexident
        self.last_seen = adsb.gen_date + adsb.gen_time
        self.position = (adsb.latitude, adsb.longitude, adsb.altitude)
        self.verticalrate = adsb.verticalrate
        self.onground = adsb.onground

        # Update only if msg includes coordinates
        self.__flight_track_positions.append(self.position)
        self.__flight_track_timestamps.append(self.last_seen)


if __name__ == '__main__':
    flight = Flight('dummy')

    message_source = adsb_parser.FileSource('messages.txt')

    i = 0
    start = time.time()
    for msg in adsb_parser.AdsbMessage(message_source):
        flight.update(msg)
        i += 1
        log.info(flight.__dict__)

    duration = time.time() - start
    print("{} operations in {}sec".format(i, duration))