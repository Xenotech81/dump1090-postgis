import logging
import queue
import threading

from dump1090_postgis.adsb_parser import AdsbMessage, MessageStream
from dump1090_postgis.flights import CurrentFlights

log = logging.getLogger()


class AdsbLogger:
    """Multi-thread logger which directs ADSB messages from the socket to the flights pool.

    Main thread: Pops ADSB messages from the queue and feeds them to the flights pool.
    Thread-1: Retrieves ADSB messages from the socket and adds them to the queue.

    Start the main loop by calling log(), stop by calling shutdown(). The worker thread always initiates stopping by
    putting a special message into the queue. There are two stop messages possible:
    1. _SENTINEL:  When shutdown() was called from outside.
    2. queue.Full instance: When the queue overfilled.

    In both cases the threads are joined in a controlled manner.
    """
    _SENTINEL = object()
    QSIZE = 10000

    def __init__(self, message_source: MessageStream, flights_pool: CurrentFlights):
        """Construct from message source (MessageStream instance) and message target (Flights instance)."""
        self._shutdown = False
        self._qsize_max = 0
        self._message_source = message_source
        self._flights_pool = flights_pool
        self._message_queue = queue.Queue(maxsize=AdsbLogger.QSIZE)
        self._receiver_thread = threading.Thread(target=self._message_receiver)

    @property
    def qsize_max(self):
        return self._qsize_max

    def log(self):
        """Main loop of the logger, pops messages from the queue."""
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
        """Thread-1 worker which pushes ADSB messages into the queue."""

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
        """Trigger graceful shutdown of the logger."""
        self._shutdown = True
