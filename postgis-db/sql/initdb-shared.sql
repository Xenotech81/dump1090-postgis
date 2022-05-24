
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO dump1090;
GRANT USAGE ON SCHEMA public TO graphql;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dump1090;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO graphql;


----------------------------- SEQUENCES--------------------------------------
-- SEQUENCE: aircraft_id_seq
-- DROP SEQUENCE aircraft_id_seq;
CREATE SEQUENCE aircraft_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 2147483647
    CACHE 1;


-- SEQUENCE: airlines_id_seq
-- DROP SEQUENCE airlines_id_seq;
CREATE SEQUENCE airlines_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 2147483647
    CACHE 1;


-- SEQUENCE: airports_id_seq
-- DROP SEQUENCE airports_id_seq;
CREATE SEQUENCE airports_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 1000
    CACHE 1;


-- SEQUENCE: runways_id_0_seq
-- DROP SEQUENCE runways_id_0_seq;
CREATE SEQUENCE runways_id_0_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 2147483647
    CACHE 1;


------------------------------- TABLES --------------------------------------
-- Table: aircraft
-- DROP TABLE aircraft;
CREATE TABLE IF NOT EXISTS aircraft
(
    id integer NOT NULL DEFAULT nextval('aircraft_id_seq'::regclass),
    model character varying(20) COLLATE pg_catalog."default" NOT NULL,
    silhouette bytea NOT NULL,
    CONSTRAINT aircraft_pkey PRIMARY KEY (id)
)
WITH (
    OIDS = FALSE
);
GRANT SELECT ON TABLE aircraft TO dump1090;
GRANT REFERENCES, SELECT ON TABLE aircraft TO graphql;


-- Index: model_idx
-- DROP INDEX model_idx;
CREATE INDEX model_idx
    ON aircraft USING btree
    (model COLLATE pg_catalog."default" ASC NULLS LAST);


-- Table: airlines
-- DROP TABLE airlines;
CREATE TABLE IF NOT EXISTS airlines
(
    id integer NOT NULL DEFAULT nextval('airlines_id_seq'::regclass),
    name character varying(255) COLLATE pg_catalog."default",
    alias character varying(50) COLLATE pg_catalog."default",
    iata character varying(10) COLLATE pg_catalog."default",
    icao character varying(10) COLLATE pg_catalog."default",
    callsign character varying(50) COLLATE pg_catalog."default",
    country character varying(50) COLLATE pg_catalog."default",
    active character varying(1) COLLATE pg_catalog."default",
    CONSTRAINT airlines_pkey PRIMARY KEY (id)
)
WITH (
    OIDS = FALSE
);

GRANT SELECT ON TABLE airlines TO dump1090;
GRANT REFERENCES, SELECT ON TABLE airlines TO graphql;

COMMENT ON TABLE airlines
    IS 'Airlines info: Use to map from 3-letter flight callsign to full airline name. \n Attibution: https://resources.oreilly.com/learning-paths/graph-algorithms-in-practice/tree/master/data';


-- Table: airports
-- DROP TABLE airports;
CREATE TABLE IF NOT EXISTS airports
(
    icao character varying(4) COLLATE pg_catalog."default" NOT NULL,
    iata character varying(3) COLLATE pg_catalog."default" NOT NULL,
    name text COLLATE pg_catalog."default" NOT NULL,
    city text COLLATE pg_catalog."default",
    latlon geometry(Point,4326) NOT NULL,
    bbox geometry(Polygon,4326) NOT NULL,
    altitude double precision NOT NULL,
    country text COLLATE pg_catalog."default",
    locale text COLLATE pg_catalog."default" NOT NULL,
    timezone text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT airports_pk PRIMARY KEY (icao),
    CONSTRAINT check_valid_bbox CHECK (st_isvalid(bbox)),
    CONSTRAINT enforce_srid_4326 CHECK (st_srid(latlon) = 4326)
)
WITH (
    OIDS = FALSE
);
GRANT SELECT ON TABLE airports TO dump1090;
GRANT SELECT ON TABLE airports TO graphql;

COMMENT ON TABLE airports
    IS 'Airport definition: Description, timezone, bbox (polygon) and lat/lon (point) geometries (except runways)';

COMMENT ON COLUMN airports.latlon
    IS 'Geometry point';
COMMENT ON COLUMN airports.altitude
    IS 'Altitude ASL';

COMMENT ON CONSTRAINT check_valid_bbox ON airports
    IS 'Allow only valid polygon geometry for bbox';
COMMENT ON CONSTRAINT enforce_srid_4326 ON airports
    IS 'Allow only 4326 as SRID';


-- Table: countries
-- DROP TABLE countries;
CREATE TABLE IF NOT EXISTS countries
(
    id integer NOT NULL,
    code character(2) COLLATE pg_catalog."default" NOT NULL,
    name text COLLATE pg_catalog."default" NOT NULL,
    continent character(2) COLLATE pg_catalog."default",
    wikipedia_link text COLLATE pg_catalog."default",
    keywords text COLLATE pg_catalog."default",
    CONSTRAINT countries_pkey PRIMARY KEY (id)
)
WITH (
    OIDS = FALSE
);

GRANT SELECT ON TABLE countries TO dump1090;
GRANT REFERENCES, SELECT ON TABLE countries TO graphql;

COMMENT ON TABLE countries
    IS 'Country name to alpha-2 code mapping';

-- Custom table, NTE only!
-- Table: runways
-- DROP TABLE runways;
CREATE TABLE IF NOT EXISTS runways
(
    id integer NOT NULL DEFAULT nextval('runways_id_0_seq'::regclass),
    geom geometry(Polygon,4326),
    airport_icao character varying(4) COLLATE pg_catalog."default",
    name character varying(255) COLLATE pg_catalog."default",
    direction integer,
    length double precision,
    CONSTRAINT runways_pkey PRIMARY KEY (id),
    CONSTRAINT airports_icao_fk FOREIGN KEY (airport_icao)
        REFERENCES airports (icao) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE
        NOT VALID
)
WITH (
    OIDS = FALSE
);

GRANT SELECT ON TABLE runways TO dump1090;
GRANT REFERENCES, SELECT ON TABLE runways TO graphql;

------------------------------- VIEWS----------------------------------------
-- View: airports_geojson
-- DROP VIEW airports_geojson;
CREATE OR REPLACE VIEW airports_geojson
 AS
 SELECT airports.icao,
    airports.iata,
    airports.name,
    airports.city,
    airports.altitude,
    airports.country,
    airports.locale,
    airports.timezone,
    st_asgeojson(airports.bbox, 6)::json AS bbox,
    st_asgeojson(airports.latlon, 6)::json AS latlon
   FROM airports;

GRANT ALL ON TABLE airports_geojson TO dump1090;
GRANT SELECT, REFERENCES ON TABLE airports_geojson TO graphql;

COMMENT ON VIEW airports_geojson
    IS 'Same as airports table, but with Bbox and latlon as geoJSON';


----------------------------- FUNCTIONS--------------------------------------
-- FUNCTION: load_aircraft(text)
-- DROP FUNCTION load_aircraft(text);
CREATE OR REPLACE FUNCTION load_aircraft(
	dir text DEFAULT '/postgis-db/data/silhouettes/'::text)
    RETURNS integer
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
  rec RECORD;
BEGIN
  RAISE NOTICE 'Loading aircraft silhouette BMPs...';
  FOR rec IN select pg_ls_dir(dir) AS fn LOOP
	IF (rec.fn ~ '.bmp$') THEN
	  INSERT INTO aircraft (model, silhouette)  VALUES (split_part(rec.fn, '.', 1), pg_read_binary_file(dir || rec.fn));
	END IF;
END LOOP;
RAISE NOTICE 'Done. Number of aircraft inserted: ';
RETURN (select count(*) from aircraft);
END;
$BODY$;
