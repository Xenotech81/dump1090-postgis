from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DATETIME
from geoalchemy2 import Geometry
# https://geoalchemy-2.readthedocs.io/en/latest/shape.html
from geoalchemy2.shape import from_shape
from shapely.geometry import LineString
import datetime
import logging
import string
import time

import adsb_parser

log = logging.getLogger(__name__)

Base = declarative_base()

# Spatial Reference Id of the flight path xy coordinates
SRID = 4326
# Unit of the flight altitude to save in the database ['m', 'ft']
ALT_UNIT = 'm'


def feet2m(ft):
    """
    Computes and returns length in m from feet.
    :param ft: Length in feet
    :return: Length in meter
    """
    return 0.3048 * ft


class Flight(Base):
    __tablename__ = 'flights'
    id = Column(Integer, primary_key=True)
    hexident = Column(String, nullable=False)
    first_seen = Column(DATETIME, nullable=False)
    groundtrack = Geometry('LINESTRING', srid=SRID)

    def __init__(self, hexident: string):
        self.hexident = hexident
        # Time stamp of last received message
        self.last_seen = None
        # Last position (not necessarily from last message)
        self.position = None
        self.verticalrate = None
        self.squawk = None
        self.onground = True
        self.__groundtrack = []
        self.__altitudes = []  # List of altitudes [m]
        self.__times = []
        self._transmission_type_count = dict.fromkeys(range(1, 9, 1), 0)

    def _add_position(self, x: float, y: float, z: float, t: datetime.datetime):
        """
        Adds x,y coordinates and timestamp of a single filight path position.
        :param x: x coordinate
        :param y: y coordinate
        :param z: height above ground [m]
        :param t: timestamp
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
            log.debug(
                "Trying to update flight '{}' with ADSb message of flight '{}'".format(self.hexident, adsb.hexident))
            return self

        self._transmission_type_count[adsb.transmission_type] += 1

        if not self.first_seen:
            self.first_seen = adsb.gen_date_time
            print(datetime.datetime.timestamp(self.first_seen))

        self.last_seen = adsb.gen_date_time

        try:
            for field in MSG_FIELDS[adsb.transmission_type]:
                setattr(self, field, getattr(adsb, field))
        except KeyError:
            log.debug("Skipping updating flights with transmission type {:d}".format(adsb.transmission_type))

        # Update only if msg includes coordinates
        if adsb.transmission_type == 3:
            self._add_position(adsb.latitude, adsb.longitude, adsb.altitude, adsb.gen_date_time)

        return self


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)

    message_source = adsb_parser.FileSource('messages_long.txt')
    flight = Flight('405D0F')

    i = 0
    start = time.time()
    for msg in adsb_parser.AdsbMessage(message_source):
        flight.update(msg)
        i += 1

    duration = time.time() - start
    log.info("{} operations in {}sec".format(i, duration))

    log.info(list(flight.flight_path()))

