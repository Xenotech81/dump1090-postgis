#!/bin/bash

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Create the 'template_icao' template db
"${psql[@]}" <<- 'EOSQL'
CREATE DATABASE template_icao TEMPLATE template_postgis IS_TEMPLATE true;
EOSQL

# Create the 'shared' db
"${psql[@]}" <<- 'EOSQL'
CREATE DATABASE shared;
EOSQL


"${psql[@]}" --dbname=template_icao < sql/initdb-users.sql
"${psql[@]}" --dbname=template_icao < sql/initdb-template.sql
"${psql[@]}" --dbname=template_icao < sql/initdb-shared.sql

# Create the first airport DB from template (if AIRPORT_ICAO was set)
if [ -v "$AIRPORT_ICAO" ]; then
  createdb -T template_icao "$AIRPORT_ICAO";
fi