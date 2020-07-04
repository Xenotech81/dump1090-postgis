import logging
import signal
import sys

from dbmanager import session
from dump1090_postgis.adsb_parser import AdsbMessageFilter, AdsbMessage, Dump1090Socket
from dump1090_postgis.flights import CurrentFlights


# https://stackoverflow.com/questions/8162419/python-logging-specific-level-only
class LevelOnlyFilter:
    def __init__(self, level):
        self.__level = level

    def filter(self, record):
        return record.levelno <= self.__level


STDOUT_LEVEL = logging.INFO

log = logging.getLogger()

stdout = logging.StreamHandler(sys.stdout)
stdout.setLevel(STDOUT_LEVEL)
stdout.addFilter(LevelOnlyFilter(STDOUT_LEVEL))
stderr = logging.StreamHandler(sys.stderr)
stderr.setLevel(logging.ERROR)

log.addHandler(stdout)
log.addHandler(stderr)


def handle_sigterm():
    """Handle Docker's SIGTERM by raising KeyboardInterrupt."""

    def exit_gracefully(signum, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, exit_gracefully)


def main():
    log.info(">>> WELCOME TO THE ADSB POSTGIS LOGGER <<<")

    handle_sigterm()

    current_flights = CurrentFlights(session=session, adsb_filter=AdsbMessageFilter(below=10000))

    message_source = Dump1090Socket()

    log.info("Start logging messages...")
    try:
        for msg in AdsbMessage(message_source):
            current_flights.update(msg)
    except KeyboardInterrupt:
        log.info("Shutting down ADSb logging service")
        session.close()


if __name__ == "__main__":
    sys.exit(main())
