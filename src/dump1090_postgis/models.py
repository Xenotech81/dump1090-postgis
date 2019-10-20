# from geoalchemy2 import Geometry
import logging
import string
import time
import pandas

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
        self._flight_track = pandas.DataFrame(columns=['time', 'x', 'y', 'z'])
        self.__flight_track_positions = []
        self.__flight_track_timestamps = []
        self._transmission_type_count = dict.fromkeys(range(1, 9, 1), 0)

    def flight_track(self):
        """
        Returns a iterator over tuples of timestamp and xyz coordinates.
        :return: Iterator of (time, (x, y, z))
        """
        return ((t, xyz) for t, xyz in zip(self.__flight_track_timestamps, self.__flight_track_positions))

    def update(self, adsb: adsb_parser.AdsbMessage):
        """
        Updates the instance attributes with values from an ADSb message object and returns.

        MSG types and contained info:
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

        MSG_FIELDS = {2: ('speed', 'latitude', 'longitude', 'onground'),
                      3: ('altitude', 'latitude', 'longitude'),
                      4: ('speed', 'track', 'verticalrate', 'onground'),
                      8: ('onground',)
                      }

        if adsb.hexident != self.hexident:
            log.error("Trying to update flight '{}' with ADSb message of flight '{}'".format(self.hexident, adsb.hexident))
            return self

        self._transmission_type_count[adsb.transmission_type] += 1
        self.last_seen = adsb.gen_date_time

        try:
            for field in MSG_FIELDS[adsb.transmission_type]:
                setattr(self, field, getattr(adsb, field))
        except KeyError:
            log.debug("Skipping updating flights with transmission type {:d}".format(adsb.transmission_type))

        # Update only if msg includes coordinates
        if adsb.transmission_type == 3:
            self.position = (adsb.latitude, adsb.longitude, adsb.altitude)
            self.__flight_track_positions.append(self.position)
            self.__flight_track_timestamps.append(self.last_seen)

        return self


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
    log.debug("{} operations in {}sec".format(i, duration))