import logging

import click as click
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import sessionmaker
from sqlalchemy_utils import database_exists, create_database, drop_database

from config import DB_URL, POSTGRES_DB

import src.dump1090_postgis.models

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)


def get_db_session(_engine):
    """Connecto to database and return an instance of sqlalchemy.orm.session.Session."""
    try:
        log.info("Connecting to PostGIS database on URL={}".format(_engine.url))
        _engine.connect()
    except OperationalError as err:
        print(str(err))
        exit(1)

    if database_exists(_engine.url):
        Session = sessionmaker(bind=_engine)
        return Session()
    else:
        raise ConnectionError("Database {} does not exist on URL {}".format(POSTGRES_DB, DB_URL))


engine = create_engine(DB_URL, echo=False)
session = get_db_session(engine)


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
def createtables():
    """Creates all tables if not existent"""

    print('Creating tables.')
    src.dump1090_postgis.models.Base.metadata.create_all(engine)
    print('done')


if __name__ == '__main__':
    cli()
