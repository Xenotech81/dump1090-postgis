import logging

import click as click
from contextlib import contextmanager
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import sessionmaker
from sqlalchemy_utils import database_exists, create_database, drop_database
from sqlalchemy.exc import DBAPIError  # SQLAlchemyError
from config import DB_URL, POSTGRES_DB

from dump1090_postgis.airports import nte_airport
from dump1090_postgis.shared import interpolate_track

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
    """Provide a transactional scope around a series of operations."""
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


@click.group()
def cli():
    """Postgre DB management commands"""


@cli.command(name='resetdb')
def resetdb_command():
    """Destroys and re-creates an empty database.
    ATTENTION: The newly created DB does not have the GIS extention!"""

    if database_exists(DB_URL):
        print('Deleting database.')
        drop_database(DB_URL)

    if not database_exists(DB_URL):
        print('Creating database.')
        create_database(DB_URL)

    print('done')


@cli.command()
def create_tables():
    """Creates all tables if not existent"""
    from dump1090_postgis import models

    print('Creating tables.')
    try:
        models.Base.metadata.create_all(engine)
        print('done')
    except DBAPIError as err:
        log.warning("Cannot create tables: %s", str(err))


@cli.command()
def create_flight_table():
    """
    Recreates flights table in DB.
    L(https://docs.sqlalchemy.org/en/13/core/exceptions.html)
    """
    from dump1090_postgis import models

    if database_exists(DB_URL):
        try:
            models.Flight.__table__.create(engine)
            models.Position.__table__.create(engine)
        except DBAPIError as err:
            log.warning("Cannot create table: %s", str(err))
    else:
        raise RuntimeError("DB {} does not exist".format(DB_URL))


@cli.command()
def delete_flight_table():
    """
    Deletes flights table in DB.
    L(https://docs.sqlalchemy.org/en/13/core/exceptions.html)
    """
    if database_exists(DB_URL):
        try:
            models.Position.__table__.drop(engine)
            models.Flight.__table__.drop(engine)
        except DBAPIError as err:
            log.warning("Cannot delete table: %s", str(err))
    else:
        raise RuntimeError("DB {} does not exist".format(DB_URL))


@cli.command()
def rebuild_landings_and_takeoffs():
    """Scans all flights in Flights table and identifies landing and takeoff events.

    If an existing event is found in the Landings or Takeoffs tables for a given flight (equivalence means same
    flight_id and same timestamp), then the runway is updated only if there are differences. If no record for the
    event can be found in the tables, a new record is created.

    ATTENTION:
    -  Only the first landing or takeoff event of a flight is considered.
    -  Only the first hit from the database is compared against; if there are more events for a given flight_id,
    they are ignored.

    NOTE:
        For each flight a new DB session is established and closed after processing if its positions set.

    TODO #11: Consider several landing and takeoff events for same flight!
    """

    from dump1090_postgis.models import Flight, Position, Takeoffs, Landings

    log = logging.getLogger()
    log.setLevel(logging.WARNING)

    with session_scope(schema='public') as session:
        flights = session.query(Flight).filter(Flight.id >= 6223).order_by(Flight.first_seen).all()
        flight_ids = [f.id for f in flights if f.callsign != 'SAMU44']  # SAMU44 takes off vertically!

    for flight_id in flight_ids:
        print("Processing FlightID:", flight_id)

        airborne_idx = None
        touchdown_idx = None

        with session_scope(schema='public') as session_p:
            positions = session_p.query(Position).filter(Position.flight_id == flight_id).order_by(
                Position.time).all()

            if len(positions) == 0:
                print("ERR: FlightId {} does not have any positions!".format(flight_id))
                continue
            if len(positions) == 1:
                print("ERR: FlightId {} has only one position!".format(flight_id))
                continue

            # First look for takeoffs
            if positions[0].onground:
                try:
                    airborne_idx = [p.onground for p in positions].index(False)  # Index is zero based
                except ValueError:
                    print("FlightId {} never took off. Skipping".format(flight_id))
                    continue
            # Now look for landings
            else:
                try:
                    touchdown_idx = [p.onground for p in positions].index(True)  # Index is zero based
                except ValueError:
                    print("FlightId {} never landed. Skipping".format(flight_id))
                    continue

            if airborne_idx:
                track = interpolate_track(positions[airborne_idx - 1: airborne_idx + 1])
                takeoff_runway = nte_airport.get_runway(positions[airborne_idx].point, track)

                takeoff_db = session_p.query(Takeoffs).filter(Takeoffs.flight_id == flight_id).first()
                if takeoff_db:
                    print("DB entry found:", str(takeoff_db))
                    if takeoff_db.time == positions[airborne_idx].time:
                        if takeoff_runway and takeoff_runway.name == takeoff_db.runway:
                            print("Runway matches to DB:", takeoff_runway.name)
                        else:
                            print("Updating DB runway to: ", takeoff_runway.name if takeoff_runway else 'UNK')
                            takeoff_db.runway = takeoff_runway.name if takeoff_runway else 'UNK'
                else:
                    # takeoff_runway can be None, in this case 'UNK' will be saved in DB
                    new_takeoff = Takeoffs(session_p.query(Flight).get(flight_id),
                                           positions[airborne_idx], takeoff_runway)
                    print("Adding to DB:", str(new_takeoff))
                    session_p.add(new_takeoff)

                session_p.commit()

            if touchdown_idx:
                track = interpolate_track(positions[touchdown_idx - 1: touchdown_idx + 1])
                landing_runway = nte_airport.get_runway(positions[touchdown_idx].point, track)

                landing_db = session_p.query(Landings).filter(Landings.flight_id == flight_id).first()
                if landing_db:
                    print("DB entry found:", str(landing_db))
                    if landing_db.time == positions[touchdown_idx].time:
                        if landing_runway and landing_runway.name == landing_db.runway:
                            print("Runway matches to DB:", landing_runway.name)
                        else:
                            print("Updating DB runway to: ", landing_runway.name if landing_runway else 'UNK')
                            landing_db.runway = landing_runway.name if landing_runway else 'UNK'
                else:
                    # landing_runway can be None, in this case 'UNK' will be saved in DB
                    new_landing = Landings(session_p.query(Flight).get(flight_id), positions[
                        touchdown_idx], landing_runway)
                    print("Adding to DB:", str(new_landing))
                    session_p.add(new_landing)

                session_p.commit()


if __name__ == '__main__':
    cli()
