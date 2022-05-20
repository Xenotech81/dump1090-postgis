# Pseudo-code instructions on how to copy data from CSV files into the DB

# Use psql:
psql -U dump1090 -d dump1090

# Add aircraft silouhettes to meta schema
# From outside the container:
 - docker cp database postgis:/database
# Again, inside container
 - mkdir -p /database/data/silhouettes
 - unzip silhouttes.zip to /database/data/silhouettes
 - psql-execute: /database/sql/create_meta_schema.sql
 - psql-execute: \copy meta.airlines (name, alias, iata, icao, callsign, country, active) FROM '/database/data/airlines.csv' DELIMITER ',' CSV HEADER QUOTE '"' ESCAPE '''' NULL '\N';
 - call sql method: select meta.load_aircraft()

# Add countries data to meta.countries
psql-execute: \copy meta.countries ("id","code","name","continent","wikipedia_link","keywords") FROM '/database/countries.csv' DELIMITER ',' CSV HEADER QUOTE '"' ESCAPE '''' NULL '\N';
