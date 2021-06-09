import logging
import signal
import sys

from db import session
from dump1090_postgis.adsb_logger import AdsbLogger
from dump1090_postgis.adsb_parser import AdsbMessageFilter, Dump1090Socket
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

    flights_pool = CurrentFlights(session=session, adsb_filter=AdsbMessageFilter(below=10000))
    adsb_logger = AdsbLogger(message_source=Dump1090Socket(), flights_pool=flights_pool)

    try:
        log.info("Start logging messages...")
        adsb_logger.log()
    except KeyboardInterrupt:
        log.info("Termination signal received. Shutting down logger and closing database connection")
        adsb_logger.shutdown()
        log.info("Maximum queue size: {}".format(adsb_logger.qsize_max))
        if len(flights_pool):
            log.warning("Dropping {} flights from flight pool".format(len(flights_pool)))
        session.close()
        log.info(">>> Goodbye <<<")


if __name__ == "__main__":
    sys.exit(main())
