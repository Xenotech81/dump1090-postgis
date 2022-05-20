# Pseudo-code instructions on how to copy data from CSV files into the DB

# Use psql:
psql -U dump1090 -d dump1090

# Add aircraft silouhettes to meta schema
# From outside the container:
 - docker cp postgis-db postgis:/postgis-db
# Again, inside container
 - mkdir -p /postgis-db/data/silhouettes
 - unzip silhouttes.zip to /postgis-db/data/silhouettes
 - psql-execute: /postgis-db/sql/create_meta_schema.sql
 - psql-execute: \copy meta.airlines (name, alias, iata, icao, callsign, country, active) FROM '/postgis-db/data/airlines.csv' DELIMITER ',' CSV HEADER QUOTE '"' ESCAPE '''' NULL '\N';
 - call sql method: select meta.load_aircraft()

# Add countries data to meta.countries
psql-execute: \copy meta.countries ("id","code","name","continent","wikipedia_link","keywords") FROM '/postgis-db/countries.csv' DELIMITER ',' CSV HEADER QUOTE '"' ESCAPE '''' NULL '\N';
