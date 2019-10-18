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

# The host on which dump1090 is running
HOST = '83.155.90.184'
# Standard Dump1090 port streaming in Base Station format
PORT = 30003

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger(__name__)


class MessageStream(abc.ABC):
    """
    Abstract Base Class to be used as template for ADSB message stream generators.
    """

    def __init__(self):
        self._message_iterator = self._initiate_stream()

    def __iter__(self) -> string:
        """
        Checks for correct length and yields a new ADSB message sting.
        The iterator is created before by calling _initiate_stream().
        :return: ADSB message string
        """
        for msg in self._message_iterator:
            msg_length = len(msg.split(","))
            if msg_length == 22:
                yield msg.strip()
            else:
                log.error("Received wrong message length ({}/22). Skipping message '{}'".format(msg_length, msg))

        self._on_close()

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

        :return: Iterator of ADSB message strings (file object like)
        """


class Dump1090Socket(MessageStream):
    """
    Generator for ADSB messages received from port on hostname.

    :param hostname: Ip address of host
    :param port: Port to listen to messages on
    :return: Generator for message strings, yields one full message at a time
    """

    def __init__(self, hostname: string = HOST, port: int = PORT):
        self.port = port
        self.hostname = hostname
        super(Dump1090Socket, self).__init__()

    def _initiate_stream(self):
        """
        Returns generator for ADSB message strings received from port on hostname.
        :return: Generator for message strings
        """
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((self.hostname, int(self.port)))

        return sock.makefile()

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
            raise FileNotFoundError("Cannot read message source: {]".format(str(err)))

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
                 r'(?P<gen_date>[0-9/]+),' \
                 r'(?P<gen_time>[0-9:\.]+),' \
                 r'(?P<log_date>[0-9/]+),' \
                 r'(?P<log_time>[0-9:\.]+),' \
                 r'(?P<callsign>[\w\s]*),' \
                 r'(?P<altitude>\d*),' \
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

        log.info("Casting to data types...")
        for field, fnc in self.NORMALIZE_MSG.items():
            if field in msg_dict:
                try:
                    msg_dict[field] = fnc(msg_dict[field])
                except ValueError as err:
                    log.warning("Could not cast {}: {}".format(field, str(err)))
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


if __name__ == "__main__":

    #message_source = Dump1090Socket()
    message_source = FileSource('messages.txt')

    for msg in AdsbMessage(message_source):
        log.info(msg.__dict__)