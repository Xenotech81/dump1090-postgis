import click as click
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy_utils import database_exists, create_database, drop_database

from config import DB_URL

import src.dump1090_postgis.models

engine = create_engine(DB_URL, echo=False)
Session = sessionmaker(bind=engine)

session = Session()


@click.group()
def cli():
    """Postgre DB management commands"""


@cli.command(name='resetdb')
def resetdb_command():
    """Destroys and re-creates an empty database"""

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
