import logging
from contextlib import contextmanager
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import sessionmaker
from sqlalchemy_utils import database_exists
from config import DB_URL, POSTGRES_DB


logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)


def get_db_session(_engine):
    """Connect to database and return an instance of sqlalchemy.orm.session.Session."""
    try:
        log.info("Connecting to PostGIS database on URL={}".format(_engine.url))
        _engine.connect()
    except OperationalError as err:
        print(str(err))
        exit(1)

    if database_exists(_engine.url):
        Session = sessionmaker(bind=_engine)  # Session maker instance
        s = Session()
        # IMPORTANT: "Expire on commit" must be set to False, to prevent querying
        # the DB after every commit to update the local Python state!
        # As the roundtrip costs time, the logger will not be able to keep up with
        # follow-up messages from the flight feeder. Also, this causes unnecessary
        # load on the DB.
        s.expire_on_commit = False
        return s
    else:
        raise ConnectionError("Database {} does not exist on URL {}".format(POSTGRES_DB, DB_URL))


engine = create_engine(DB_URL, echo=False)
session = get_db_session(engine)  # To be imported by other modules


@contextmanager
def session_scope(schema='public'):
    """Provide a transactional scope around a series of operations.
    This allows querying other schemas than 'public'.
    """
    _session = get_db_session(engine)
    # Public schema must be included by default to find all functions
    if schema != 'public':
        _session.execute("SET search_path TO {}, public".format(schema))
    try:
        yield _session
        _session.commit()
    except:
        _session.rollback()
        raise
    finally:
        _session.close()
