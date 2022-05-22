FROM postgis/postgis:14-3.2-alpine

LABEL maintainer="NTE-Skyview Project - https://nte-skyview.fr"

#RUN mkdir /postgis-db
WORKDIR /postgis-db
COPY . /postgis-db/

RUN mkdir data/silhouettes &&\
  unzip -q data/silhouettes.zip -d data/

# These scripts will be automatically executed on PG initialization
COPY ./initdb-dump1090.sh /docker-entrypoint-initdb.d/20_dump1090.sh

EXPOSE 5432