# Dump1090-postgis
dump1090 stream parser which writes flight path coordinates and basic flight info into a GIS enabled PostgreSQL database (tested with [mdillon/postgis](https://hub.docker.com/r/mdillon/postgis)). The parser reads from a stream in BaseStation format, analyses and filters the messages and writes relevant information to tables in the database.

## Installation
Pull and build the image:
```bash
git clone https://github.com/Xenotech81/dump1090-postgis.git
cd dump1090-postgis
docker build -t "xenotech81/dump1090-postgis" .
```
You might have to precede this command with a `sudo` depending on your Docker configuration. 

## Quick-start
After building, run the image from Linux command line:
```bash
docker run --name dump1090-postgis --restart unless-stopped --network host xenotech81/dump1090-postgis:latest
```
Again, a `sudo` might be needed here.

## Configuration
By default it is expected that a PostGis database is running on the same network and is accessable on port 5432. The host and port of Postgis can modified by setting the environment variables during container start (using ):
* `POSTGRES_HOST` (default: localhost)
* `POSTGRES_PORT` (default: 5432)

To access the database, set also the access credential:
* `POSTGRES_USER` (default: dump1090)
* `POSTGRES_PW` (default: dump1090)
* `POSTGRES_DB` (default: dump1090)

The dump1090 stream or FlightFeeder must be accessable on the network and can be configured with following environment variables:
* `DUMP1090_HOST` (no default)
* `DUMP1090_PORT` (30003)

## Database table structure
TBD
