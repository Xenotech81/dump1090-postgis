import logging
import signal
import sys
import queue
import threading

from db import session
from dump1090_postgis.adsb_parser import AdsbMessageFilter, AdsbMessage, Dump1090Socket, MessageStream
from dump1090_postgis.flights import CurrentFlights


log = logging.getLogger()


def handle_sigterm():
    """Handle Docker's SIGTERM by raising KeyboardInterrupt."""

    def exit_gracefully(signum, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, exit_gracefully)


class AdsbLogger:
    _SENTINEL = object()
    QSIZE = 10000

    def __init__(self, message_source: MessageStream, flights_pool: CurrentFlights):
        self._shutdown = False
        self._qsize_max = 0
        self._thread_exception = None

        self._message_source = message_source
        self._flights_pool = flights_pool
        self._message_queue = queue.Queue(maxsize=AdsbLogger.QSIZE)
        self._receiver_thread = threading.Thread(target=self._message_receiver)

    def log(self):
        """Main loop of the message logger."""
        self._receiver_thread.start()

        while True:
            # Remember maximum queue size (for debugging)
            qsize = self._message_queue.qsize()
            if qsize > self._qsize_max:
                self._qsize_max = qsize
            log.debug("Current queue size: {} (max: {})".format(qsize, self._qsize_max))

            msg = self._message_queue.get()  # Queue.get() is blocking

            if isinstance(msg, AdsbMessage):
                self._flights_pool.update(msg)
            elif isinstance(msg, queue.Full):
                raise msg
            elif msg is AdsbLogger._SENTINEL:
                log.info("Termination of main logger loop demanded")
                # Put sentinel back into queue for other threads to receive
                self._message_queue.put_nowait(AdsbLogger._SENTINEL)
                log.info("Joining threads...")
                self._receiver_thread.join()
                break

        log.info("Logging loop finished")

    def _message_receiver(self):
        log.info("Message receiver thread started")

        for msg in AdsbMessage(self._message_source):
            try:
                self._message_queue.put_nowait(msg)
            except queue.Full as err:
                log.error("Max Queue size reached ({}). Dropping all ADSB messages!".format(AdsbLogger.QSIZE))
                with self._message_queue.mutex:
                    self._message_queue.queue.clear()  # Clear
                self._message_queue.put_nowait(err)
                break

            if self._shutdown:
                break

        log.info("Message receiver thread shutting down")
        self._message_queue.put_nowait(AdsbLogger._SENTINEL)
        # Here the socket should be closed!

    def shutdown(self):
        self._shutdown = True


def main():
    log.info(">>> WELCOME TO THE ADSB POSTGIS LOGGER <<<")

    handle_sigterm()
    flights_pool = CurrentFlights(session=session, adsb_filter=AdsbMessageFilter(below=35000))

    adsb_logger = AdsbLogger(message_source=Dump1090Socket(), flights_pool=flights_pool)

    log.info("Start logging messages...")
    try:
        adsb_logger.log()
    except KeyboardInterrupt:
        log.info("Termination signal received. Shutting down logger and closing database connection")
        adsb_logger.shutdown()
        log.info("Maximum queue size: {}".format(adsb_logger._qsize_max))
        if len(flights_pool):
            log.warning("Dropping {} flights from flight pool".format(len(flights_pool)))
        session.close()
        log.info(">>> Goodbye <<<")


if __name__ == "__main__":
    sys.exit(main())
