dump1090 stream parser which writes flight paths into a GIS enabled Postgres database (PostGIS).

# Docker container
Run the container with:
```bash
docker run --name dump1090-postgis --restart unless-stopped --network host dump1090-postgis:latest'
```

By default it is expected that a PostGis database is running on the same host and is accessable on port 5432. The host and port of Postgis can modified by setting the environment variables during container start:
* 'POSTGRES_HOST'
* 'POSTGRES_PORT'

To access the database, set also the access credential:
* 'POSTGRES_USER' (default: dump1090)
* 'POSTGRES_PW' (default: dump1090)
* 'POSTGRES_DB' (default: dump1090)

The dump1090 stream or FlightFeeder must be accessable on the network and can be configured with following environment variables:
* 'DUMP1090_HOST'
* 'DUMP1090_PORT'
