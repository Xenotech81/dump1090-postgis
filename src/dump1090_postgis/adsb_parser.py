"""
Parser for ADSB message streams.
Creates an instance of AdsbMessage class for each string message coming from a message source.
A message source must inherit from the template abstract base class MessageStream;
a concrete stream generator Dump1090Socket is implemented, which connects to the dump1090 port 30003.

Inspired by:
https://github.com/bzamecnik/dump1090-archive
https://github.com/slintak/adsb2influx
"""
import abc
import logging
import re
import socket
import string
from dateutil.parser.isoparser import isoparser
from config import DUMP1090_HOST, DUMP1090_PORT
from time import sleep

# The host on which dump1090 is running
dump1090_host = DUMP1090_HOST
# Standard Dump1090 port streaming in Base Station format
dump1090_port = DUMP1090_PORT

log = logging.getLogger(__name__)

_date_time_parser = isoparser(sep=',')


class MessageStream(abc.ABC):
    """
    Abstract Base Class to be used as template for ADSB message stream generators.
    """

    # Number of attempts to reconnect to the ADSb message source (e.g. socket).
    RECONNECTIONS = 5

    def __init__(self):
        try:
            self._message_iterator = self._initiate_stream()
        except ConnectionError as err:
            raise ConnectionError("Cannot initiate message stream: {}".format(str(err)))

    def __iter__(self) -> string:
        """
        Checks for correct length and yields a new ADSB message sting.
        The iterator is created before by calling _initiate_stream().
        :return: ADSB message string
        """
        while True:
            try:
                for msg in self._message_iterator:
                    msg_length = len(msg.split(","))
                    if msg_length == 22:
                        yield msg.strip()
                    else:
                        log.error("Received wrong message length ({}/22). Skipping message '{}'".format(msg_length, msg))
                        continue
            except self.exception:
                try:
                    self._message_iterator = self._initiate_stream()
                except ConnectionError as err:
                    log.critical("Connection to socket lost permanently:{}".format(str(err)))
                    break

        self._on_close()

    @property
    @abc.abstractmethod
    def exception(self):
        """Defines the exception raised if socket connection is lost. """

    @abc.abstractmethod
    def _on_close(self):
        """
        Called when the stream is exhausted.
        @todo: Reformat into a context manager
        _message_iterator can be operated on, eg to close a socket or file.
        """

    @abc.abstractmethod
    def _initiate_stream(self) -> iter:
        """
        Generator for ADSB messages.
        Must return an iterator of ADSB messages. Each message is a string of 22 comma-separated elements,
        according to format on http://woodair.net/sbs/article/barebones42_socket_data.htm

        Example string:
        MSG,8,1,1,400BE5,1,2019/10/16,20:48:00.473,2019/10/16,20:48:00.473,,,,,,,,,,,,0

        Must raise ConnectionError if RECONNECTIONS attempts to connect to message source fail.

        :return: Iterator of ADSB message strings (file object like)
        """


class Dump1090Socket(MessageStream):
    """
    Generator for ADSB messages received from port on hostname.

    :param hostname: Ip address of host
    :param port: Port to listen to messages on
    :return: Generator for message strings, yields one full message at a time
    """

    SOCKET_TIMEOUT = 1.0

    def __init__(self, hostname: string = dump1090_host, port: int = dump1090_port):
        self.port = port
        self.hostname = hostname
        super(Dump1090Socket, self).__init__()

    def _initiate_stream(self):
        """
        Returns generator for ADSB message strings received from port on hostname.
        Tries to connect RECONNECTIONS times, raises ConnectionError if all attempts fail.
        :return: Generator for message strings
        """

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(self.SOCKET_TIMEOUT)

        for attempt in range(self.RECONNECTIONS):
            try:
                sock.connect((self.hostname, int(self.port)))
                return sock.makefile()
            except (socket.error, socket.timeout) as err:
                log.error("Attempt {i]/{i_max} failed connecting to {host}:{port}: {error}.".format(i=attempt + 1,
                                                                                            i_max=self.RECONNECTIONS,
                                                                                            host=self.hostname,
                                                                                            port=int(self.port),
                                                                                            error=str(err)
                                                                                                    )
                          )
                sleep(0.5)
                continue

        log.critical("Port {}:{} unreachable".format(self.hostname, int(self.port)))
        raise ConnectionError("Port {}:{} unreachable".format(self.hostname, int(self.port)))

    @property
    def exception(self):
        return socket.error

    def _on_close(self):
        self._message_iterator.close()


class FileSource(MessageStream):

    def __init__(self, file_path: string):
        self._file_path = file_path
        super(FileSource, self).__init__()

    def _initiate_stream(self) -> iter:
        try:
            return open(self._file_path, 'r')
        except FileNotFoundError as err:
            raise ConnectionError("Cannot read file: {}".format(str(err)))

    @property
    def exception(self):
        return IOError

    def _on_close(self):
        self._message_iterator.close()


class AdsbMessage(object):
    """
    ADSb message instance created from a string in Base Station format.

    @Note: Instance attributes will be created dynamically in _update_attributes() from keys of NORMALIZE_MSG dict.

    Message parsing inspired from:
    https://github.com/slintak/adsb2influx
    """

    # Regexp pattern for MSG format.
    REGEXP_MSG = r'^MSG,' \
                 r'(?P<transmission_type>\d),' \
                 r'(?P<session>\d+),' \
                 r'(?P<aircraft>\d+),' \
                 r'(?P<hexident>[0-9A-F]+),' \
                 r'(?P<flight>\d+),' \
                 r'(?P<gen_date_time>[0-9/]+,[0-9:\.]+),' \
                 r'(?P<log_date_time>[0-9/]+,[0-9:\.]+),' \
                 r'(?P<callsign>[\w\s]*),' \
                 r'(?P<altitude>[\d\-]*),' \
                 r'(?P<speed>\d*),' \
                 r'(?P<track>[\d\-]*),' \
                 r'(?P<latitude>[\d\-\.]*),' \
                 r'(?P<longitude>[\d\-\.]*),' \
                 r'(?P<verticalrate>[\d\-]*),' \
                 r'(?P<squawk>\d*),' \
                 r'(?P<alert>[\d\-]*),' \
                 r'(?P<emergency>[\d\-]*),' \
                 r'(?P<spi>[\d\-]*),' \
                 r'(?P<onground>[\d\-]*)$'

    NORMALIZE_MSG = {
        'transmission_type': (lambda v: int(v)),
        'session': (lambda v: int(v)),
        'aircraft': (lambda v: int(v)),
        'flight': (lambda v: int(v)),
        'gen_date_time': (lambda v: _date_time_parser.isoparse(v.replace('/', '-'))),
        'log_date_time': (lambda v: _date_time_parser.isoparse(v.replace('/', '-'))),
        'callsign': (lambda v: v.strip() if v != '' else None),
        'altitude': (lambda v: int(v)),
        'speed': (lambda v: int(v)),
        'track': (lambda v: int(v)),
        'latitude': (lambda v: float(v)),
        'longitude': (lambda v: float(v)),
        'verticalrate': (lambda v: int(v)),
        'squawk': (lambda v: int(v)),
        'alert': (lambda v: True if v == '-1' else False),
        'emergency': (lambda v: True if v == '-1' else False),
        'spi': (lambda v: True if v == '-1' else False),
        'onground': (lambda v: True if v == '-1' else False),
        }

    def __init__(self, message_stream: MessageStream):
        """

        :param message_stream:
        """
        assert isinstance(message_stream, MessageStream)
        self.__message_stream = message_stream
        self.__re_msg = re.compile(self.REGEXP_MSG)

    def __str__(self):
        return str({k: self.__dict__[k] for k in self.NORMALIZE_MSG.keys()})

    def __normalize_msg(self, msg: string):
        """
        Identifies and casts field values of message string to data types and returns as dict.

        First the message string is matched against the regex '__re_msg". If the match fails (if not ALL fields could
        be identified in the string) an empty dict is returned. If the match was successful, each value of the dict
        is cast to a Python data type using methods from 'NORMALIZE_MSG'. If the cast fails for an dict item
        (when it is an empty string) None is assigned.

        :param msg: ADSB message string
        :return: Dict of fields of the message string cast to Python data types; Or empty dict if casting failed
        """
        log.debug("Normalizing: {}".format(msg))

        log.debug("Matching fields...")
        match = self.__re_msg.match(msg)
        if match is not None:
            msg_dict = match.groupdict()
        else:
            log.error("Could not identify all fields in '{}'. Skipping message.".format(msg))
            return {}

        log.debug("Casting to data types...")
        for field, fnc in self.NORMALIZE_MSG.items():
            if field in msg_dict:
                try:
                    msg_dict[field] = fnc(msg_dict[field])
                except ValueError as err:
                    log.debug("Could not cast {}: {}".format(field, str(err)))
                    msg_dict[field] = None
            else:
                log.warning("Field {} not found".format(field))
        return msg_dict

    def __update_attributes(self, attributes: dict):
        """
        Creates or updates the attributes of this instance.
        :param attributes: Dictionary of attribute names and values
        """
        for attr, value in attributes.items():
            setattr(self, attr, value)

    def __iter__(self):
        """
        Yields an instance of itself with dynamically created or updated instance attributes.
        :param msg: ADSb message string
        :return: Instance of itself updated with ADSb message values
        """
        for msg in self.__message_stream:
            self.__update_attributes(self.__normalize_msg(msg))
            yield self


class AdsbMessageFilter(object):

    def __init__(self, below: int = 100000, above=-1000, radius: int = 500000, faster: int = 0, slower: int = 30000,
                 rising: bool = None, descending: bool = None, onground: bool = None):
        """
        Filter which returns True if all conditions are fulfilled, else False.

        Defaults are chosen such that filter returns True by default. Currently, only altitude test is implemented.
        todo Implement all filter tests.

        :param below: Altitude threshold in feet AGL [ft]
        :param above: Altitude threshold in feet AGL [ft]
        :param radius: Radius about a reference point [m]
        :param faster:  Speed threshold [knots]
        :param slower: Speed threshold [knots]
        :param rising:  True / False flag
        :param descending:  True / False flag
        :param onground: True / False flag
        :return:
        """

        self.below = below
        self.above = above

        # If set to True, the message will be rejected, if parameter value to be tested is missing.
        self.strict = True

    def altitude(self, adsb: AdsbMessage) -> bool:
        """
        Checks if the reported altitude is within the requested limits.

        Returns True if the flight altitude is within the requested limits, otherwise false.
        If the ADSb message does not contain an altitude value and the filter is set to 'strict' mode,
        False is returned, otherwise True.

        :param adsb: ADSb message instance.
        :return: True/False
        """
        if self.below <= self.above:
            raise ValueError("'below' altitude condition must be higher than 'above' altitude")

        if adsb.altitude is not None:
            if self.below > adsb.altitude > self.above:
                return True
            else:
                return False
        else:
            if self.strict:
                return False
            else:
                return True

    def filter(self, adsb: AdsbMessage):
        """
        Returns True if all sub-tests return True, else False.

        The flag 'strict' determines the behaviour if the message does not contain a parameter
        which shall be tested. E.g. not all message types transmit the altitude or the position.
        If set to strict mode, such messages will be rejected by the filter (False will be returned).
        :param adsb:
        :return:
        """
        assert isinstance(adsb, AdsbMessage)
        return all((self.altitude(adsb),))


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)

    message_source = FileSource('../tests/adsb_message_hexident_40757F.txt')
    for msg in AdsbMessage(message_source):
        log.info(msg)
        # Altitude filter test:
        log.debug("Flight altitude is %s and below 10000ft: %s", msg.altitude if msg.altitude is not None else
        "Unknown", AdsbMessageFilter(below=10000).filter(msg))
