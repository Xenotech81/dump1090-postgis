#!/bin/bash

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

echo "-------- Create empty 'template_icao' template DB"
"${psql[@]}" <<-'EOSQL'
CREATE DATABASE template_icao TEMPLATE template_postgis IS_TEMPLATE true;
EOSQL

echo "-------- Create empty 'shared' DB"
"${psql[@]}" <<-'EOSQL'
CREATE DATABASE shared TEMPLATE template_postgis;
EOSQL


echo "-------- Creating DB users"
"${psql[@]}" --dbname=template_icao < sql/initdb-users.sql
# Fill 'shared' first, as 'template_icao' will connect to it with FWD
echo "-------- Filling 'shared' DB"
"${psql[@]}" --dbname=shared < sql/initdb-shared.sql
echo "-------- Filling 'template_icao' template DB"
"${psql[@]}" --dbname=template_icao < sql/initdb-template.sql

echo "-------- Copy meta data into 'shared' DB"
"${psql[@]}" --dbname=shared <<-'EOSQL'
  COPY countries FROM '/postgis-db/data/countries.csv' csv header;
  COPY airlines  FROM '/postgis-db/data/airlines.csv' csv header;
  SELECT * from load_aircraft('/postgis-db/data/silhouettes/');
EOSQL


# Create the first airport DB from template (if AIRPORT_ICAO was set)
# Steps:
# 1. Create user <ICAO> with role dump1090 (read/write)
# 2. Create DB <ICAO> as copy of template_icao and user <ICAO> as owner
# 3. Grant user <ICAO> connection privilege to DB <ICAO>
if [ -v "$AIRPORT_ICAO" ]; then
  echo "-------- Creating first airport database: $AIRPORT_ICAO"
  createdb -U postgres -T template_icao "$AIRPORT_ICAO";
fi