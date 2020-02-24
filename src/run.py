import logging
import sys

from dump1090_postgis.adsb_parser import AdsbMessageFilter, AdsbMessage, Dump1090Socket
from dump1090_postgis.flights import CurrentFlights

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)


def main():
    log.info(">>> WELCOME TO THE ADSB POSTGIS LOGGER <<<")

    from dbmanager import session
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
