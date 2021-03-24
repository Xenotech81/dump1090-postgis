--
-- Public schema tables in which flight data will be logged
--


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER SCHEMA public OWNER TO dump1090;
COMMENT ON SCHEMA public IS 'Default schema in which all flights will be logged';

SET default_tablespace = '';


--- Enums
CREATE TYPE public.intention AS ENUM (
    'enroute',
    'departure',
    'arrival',
    'unknown'
);
ALTER TYPE public.intention OWNER TO dump1090;


--- Flights
CREATE TABLE public.flights (
    id integer NOT NULL,
    hexident character varying(6) NOT NULL,
    callsign character varying(7),
    first_seen timestamp(6) with time zone NOT NULL,
    last_seen timestamp(6) with time zone,
    intention character varying(9)
);
ALTER TABLE public.flights OWNER TO dump1090;

CREATE SEQUENCE public.flights_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE public.flights_id_seq OWNER TO dump1090;
ALTER SEQUENCE public.flights_id_seq OWNED BY public.flights.id;

CREATE OR REPLACE RULE clean_positions_live AS
    ON INSERT TO public.flights
    DO
DELETE from public.positions_live
	where public.positions_live.time < NOW()::timestamptz - interval '1 day';
COMMENT ON RULE clean_positions_live ON public.flights IS 'Deletes records in positions_live table which are older than NOW minus 1day';


--- Landings
CREATE TABLE public.landings (
    id integer NOT NULL,
    flight_id integer,
    "time" timestamp(6) with time zone NOT NULL,
    runway character varying(3) NOT NULL
);
ALTER TABLE public.landings OWNER TO dump1090;

CREATE SEQUENCE public.landings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE public.landings_id_seq OWNER TO dump1090;
ALTER SEQUENCE public.landings_id_seq OWNED BY public.landings.id;


--- Positions
CREATE TABLE public.positions (
    id bigint NOT NULL,
    flight_id integer,
    "time" timestamp(6) with time zone NOT NULL,
    coordinates public.geometry(PointZ,4326),
    verticalrate smallint,
    track smallint,
    onground boolean
);
ALTER TABLE public.positions OWNER TO dump1090;

CREATE SEQUENCE public.positions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE public.positions_id_seq OWNER TO dump1090;
ALTER SEQUENCE public.positions_id_seq OWNED BY public.positions.id;

CREATE RULE copy_to_live AS
    ON INSERT TO public.positions DO  INSERT INTO public.positions_live (id, flight_id, "time", coordinates, verticalrate, track, onground)  SELECT new.id,
            new.flight_id,
            new."time",
            new.coordinates,
            new.verticalrate,
            new.track,
            new.onground;
COMMENT ON RULE copy_to_live ON public.positions IS 'Copies a new position record to positions_live table on insert.';


--- Positions_live
CREATE TABLE public.positions_live (
    id bigint NOT NULL,
    flight_id integer,
    "time" timestamp(6) with time zone NOT NULL,
    coordinates public.geometry(PointZ,4326),
    verticalrate integer,
    track integer,
    onground boolean
);
ALTER TABLE public.positions_live OWNER TO dump1090;
ALTER TABLE ONLY public.positions_live
    ADD CONSTRAINT positions_live_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;

CREATE INDEX fki_positions_flight_id_fkey ON public.positions_live USING btree (flight_id);
CREATE INDEX "idx_positions_live_time"
    ON public.positions_live USING btree
    ("time" DESC NULLS LAST)
    TABLESPACE pg_default;

--- Takeoffs
CREATE TABLE public.takeoffs (
    id integer NOT NULL,
    flight_id integer,
    "time" timestamp(6) with time zone NOT NULL,
    runway character varying(3) NOT NULL
);
ALTER TABLE public.takeoffs OWNER TO dump1090;

CREATE SEQUENCE public.takeoffs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE public.takeoffs_id_seq OWNER TO dump1090;
ALTER SEQUENCE public.takeoffs_id_seq OWNED BY public.takeoffs.id;


--- PKEYs
ALTER TABLE ONLY public.flights ALTER COLUMN id SET DEFAULT nextval('public.flights_id_seq'::regclass);
ALTER TABLE ONLY public.landings ALTER COLUMN id SET DEFAULT nextval('public.landings_id_seq'::regclass);
ALTER TABLE ONLY public.positions ALTER COLUMN id SET DEFAULT nextval('public.positions_id_seq'::regclass);
ALTER TABLE ONLY public.takeoffs ALTER COLUMN id SET DEFAULT nextval('public.takeoffs_id_seq'::regclass);

ALTER TABLE ONLY public.flights
    ADD CONSTRAINT flights_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.landings
    ADD CONSTRAINT landings_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.takeoffs
    ADD CONSTRAINT takeoffs_pkey PRIMARY KEY (id);


--- FKEYs
ALTER TABLE ONLY public.landings
    ADD CONSTRAINT landings_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.takeoffs
    ADD CONSTRAINT takeoffs_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;

