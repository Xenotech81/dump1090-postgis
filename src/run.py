import logging
import signal
import sys

from dbmanager import session
from dump1090_postgis.adsb_parser import AdsbMessageFilter, AdsbMessage, Dump1090Socket
from dump1090_postgis.flights import CurrentFlights


log = logging.getLogger()


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
        log.info("Shutting down ADSb logging service and closing database connection")
        session.close()
        log.info(">>> Goodbye <<<")


if __name__ == "__main__":
    sys.exit(main())
