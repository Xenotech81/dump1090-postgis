--
-- PostgreSQL database dump
--

-- Dumped from database version 11.2 (Debian 11.2-1.pgdg90+1)
-- Dumped by pg_dump version 12.0

-- Started on 2021-08-01 13:07:59 UTC

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

--
-- TOC entry 4802 (class 1262 OID 29021)
-- Name: dump1090; Type: DATABASE; Schema: -; Owner: dump1090
--

CREATE DATABASE dump1090 WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.utf8' LC_CTYPE = 'en_US.utf8';


ALTER DATABASE dump1090 OWNER TO dump1090;

\connect dump1090

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

--
-- TOC entry 4804 (class 0 OID 0)
-- Name: dump1090; Type: DATABASE PROPERTIES; Schema: -; Owner: dump1090
--

ALTER DATABASE dump1090 SET search_path TO '$user', 'public', 'topology';


\connect dump1090

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

--
-- TOC entry 19 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: dump1090
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO dump1090;

--
-- TOC entry 4805 (class 0 OID 0)
-- Dependencies: 19
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: dump1090
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 2319 (class 1247 OID 40784)
-- Name: events_histogram_type; Type: TYPE; Schema: public; Owner: dump1090
--

CREATE TYPE public.events_histogram_type AS (
	datetime timestamp with time zone,
	events bigint,
	flight_ids integer[]
);


ALTER TYPE public.events_histogram_type OWNER TO dump1090;

--
-- TOC entry 4807 (class 0 OID 0)
-- Dependencies: 2319
-- Name: TYPE events_histogram_type; Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON TYPE public.events_histogram_type IS 'Record type for event histogram data: date or time, Nr of events, array of flight_ids';


--
-- TOC entry 2081 (class 1247 OID 29028)
-- Name: intention; Type: TYPE; Schema: public; Owner: dump1090
--

CREATE TYPE public.intention AS ENUM (
    'enroute',
    'departure',
    'arrival',
    'unknown'
);


ALTER TYPE public.intention OWNER TO dump1090;

--
-- TOC entry 2322 (class 1247 OID 42782)
-- Name: peak_hour_type; Type: TYPE; Schema: public; Owner: dump1090
--

CREATE TYPE public.peak_hour_type AS (
	peak_hour timestamp with time zone,
	count smallint
);


ALTER TYPE public.peak_hour_type OWNER TO dump1090;

--
-- TOC entry 4809 (class 0 OID 0)
-- Dependencies: 2322
-- Name: TYPE peak_hour_type; Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON TYPE public.peak_hour_type IS 'Type describing the peak hour and count of landing or takeoff events';


--
-- TOC entry 1691 (class 1255 OID 33762)
-- Name: d1090_copy_flight(bigint); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.d1090_copy_flight(f_id bigint, OUT new_id bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$BEGIN
	WITH moved_flight AS (
		INSERT INTO public.flights (hexident, callsign, first_seen, last_seen, intention)
		SELECT hexident, callsign, first_seen, last_seen, intention from dev.flights f
		WHERE f.id = f_id
		RETURNING id
		),
		moved_positions AS (
			INSERT INTO public.positions(flight_id, time, coordinates, onground) SELECT (SELECT id FROM moved_flight), p.time, p.coordinates, p.onground FROM dev.positions p
			WHERE p.flight_id = f_id
			ORDER BY time ASC
		),
		moved_landings AS (
			INSERT INTO public.landings(flight_id, time, runway) SELECT (SELECT id FROM moved_flight), l.time, l.runway FROM dev.landings l
			WHERE l.flight_id = f_id
		),
		moved_takeoffs AS (
			INSERT INTO public.takeoffs(flight_id, time, runway) SELECT (SELECT id FROM moved_flight), t.time, t.runway FROM dev.takeoffs t
			WHERE t.flight_id = f_id
		)
	SELECT id FROM moved_flight into new_id;
END;$$;


ALTER FUNCTION public.d1090_copy_flight(f_id bigint, OUT new_id bigint) OWNER TO dump1090;

--
-- TOC entry 1692 (class 1255 OID 40785)
-- Name: events_histogram(timestamp with time zone, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.events_histogram(starts timestamp with time zone DEFAULT CURRENT_DATE, ends timestamp with time zone DEFAULT CURRENT_DATE, bin text DEFAULT 'hour'::text) RETURNS SETOF public.events_histogram_type
    LANGUAGE sql STABLE
    AS $$
SELECT t1.interval as "time",
       t2.events,
	   flight_ids
FROM   (SELECT "interval"
        FROM   generate_series(date_trunc(bin, starts::TIMESTAMP AT TIME ZONE 'UTC'), date_trunc(bin, (ends + interval '23 hours')::TIMESTAMP AT TIME ZONE 'UTC'), CONCAT('1 ', bin)::interval) AS "interval") t1
       LEFT OUTER JOIN (SELECT date_trunc(bin, time) as "interval",
                               COUNT(flight_id) events,
							   array_agg(flight_id) as flight_ids
                        FROM   landings
                        GROUP  BY "interval") t2
                    ON t1.interval = t2.interval
ORDER BY "time" ASC;
$$;


ALTER FUNCTION public.events_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text) OWNER TO dump1090;

--
-- TOC entry 1695 (class 1255 OID 33686)
-- Name: flight_path(bigint); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.flight_path(flight_id bigint) RETURNS public.geometry
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
	RETURN st_makeline(st_force2d(p.coordinates) ORDER BY p.time) FROM flights f
	JOIN public.positions p on f.id = p.flight_id
	WHERE f.id = flight_path.flight_id;
END
$$;


ALTER FUNCTION public.flight_path(flight_id bigint) OWNER TO dump1090;

--
-- TOC entry 1696 (class 1255 OID 39082)
-- Name: flight_path_geojson(bigint); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.flight_path_geojson(flight_id bigint) RETURNS json
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
	RETURN ST_AsGeoJSON(st_makeline(st_force2d(p.coordinates) ORDER BY p.time)) FROM flights f
	JOIN public.positions p on f.id = p.flight_id
	WHERE f.id = flight_path_geojson.flight_id;
END
$$;


ALTER FUNCTION public.flight_path_geojson(flight_id bigint) OWNER TO dump1090;

--
-- TOC entry 1689 (class 1255 OID 39330)
-- Name: flight_paths(bigint[]); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.flight_paths(flight_ids bigint[]) RETURNS SETOF json
    LANGUAGE plpgsql STABLE
    AS $$
declare
flight_id bigint;

begin
	foreach flight_id in array flight_ids loop
		return next flight_path_geojson(flight_id);
	end loop;
end
$$;


ALTER FUNCTION public.flight_paths(flight_ids bigint[]) OWNER TO dump1090;

--
-- TOC entry 1686 (class 1255 OID 37390)
-- Name: landings_hist_on(date); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.landings_hist_on(mydate date DEFAULT CURRENT_DATE) RETURNS SETOF record
    LANGUAGE sql STABLE
    AS $$select date_trunc('hour', "time") "hour", count(id) landings from landings
WHERE landings.time >= mydate
AND landings.time < (mydate + 1)
group by date_trunc('hour', "time")
order by "hour" asc$$;


ALTER FUNCTION public.landings_hist_on(mydate date) OWNER TO dump1090;

--
-- TOC entry 4814 (class 0 OID 0)
-- Dependencies: 1686
-- Name: FUNCTION landings_hist_on(mydate date); Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON FUNCTION public.landings_hist_on(mydate date) IS 'Return full hour timestamp with tz and landings count';


--
-- TOC entry 1697 (class 1255 OID 41728)
-- Name: landings_histogram(timestamp with time zone, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.landings_histogram(starts timestamp with time zone DEFAULT CURRENT_DATE, ends timestamp with time zone DEFAULT CURRENT_DATE, bin text DEFAULT 'hour'::text) RETURNS SETOF public.events_histogram_type
    LANGUAGE sql STABLE
    AS $$
SELECT t1."interval" as "time",
       t2.events,
	   flight_ids
FROM   (SELECT "interval" at time zone 'Europe/Paris' as "interval"
        FROM   generate_series(date_trunc(bin, starts::date)::timestamp, date_trunc(bin, ends::date)::timestamp, CONCAT('1 ', bin)::interval) AS "interval") t1
       LEFT OUTER JOIN (SELECT date_trunc(bin, "time" at time zone 'Europe/Paris') at time zone 'Europe/Paris' as "interval",
                               COUNT(flight_id) events,
							   array_agg(flight_id) as flight_ids
                        FROM   landings
                        GROUP  BY "interval") t2
                    ON t1."interval" = t2."interval"
ORDER BY "time" ASC;
$$;


ALTER FUNCTION public.landings_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text) OWNER TO dump1090;

SET default_tablespace = '';

--
-- TOC entry 210 (class 1259 OID 29039)
-- Name: landings; Type: TABLE; Schema: public; Owner: dump1090
--

CREATE TABLE public.landings (
    id integer NOT NULL,
    flight_id integer,
    "time" timestamp(6) with time zone NOT NULL,
    runway character varying(3) NOT NULL
);


ALTER TABLE public.landings OWNER TO dump1090;

--
-- TOC entry 1693 (class 1255 OID 37234)
-- Name: landings_on(date); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.landings_on(mydate date DEFAULT CURRENT_DATE) RETURNS SETOF public.landings
    LANGUAGE sql STABLE
    AS $$SELECT * FROM landings
	WHERE landings.time >= mydate
	AND landings.time < (mydate + 1)
	ORDER BY landings.time asc;$$;


ALTER FUNCTION public.landings_on(mydate date) OWNER TO dump1090;

--
-- TOC entry 1698 (class 1255 OID 43047)
-- Name: peak_hour_all(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.peak_hour_all(startdate timestamp with time zone DEFAULT CURRENT_DATE, enddate timestamp with time zone DEFAULT (CURRENT_DATE + '1 day'::interval)) RETURNS SETOF public.peak_hour_type
    LANGUAGE sql STABLE
    AS $$
-- https://blog.jooq.org/2016/10/31/a-little-known-sql-feature-use-logical-windowing-to-aggregate-sliding-ranges/
-- https://stackoverflow.com/questions/31345344/sql-query-find-daily-min-max-and-times-when-the-min-and-max-values-occurred

with cte as (
	select
		p."peak_hour",
		p."events",
		row_number() over (partition by date(p.peak_hour at time zone 'Europe/Paris') order by p."events" desc, p.peak_hour desc) rnmax
		from
			(select
				date_trunc('m', "time" - '30 minutes'::interval) peak_hour,
				COUNT(*) OVER (
					ORDER BY "time"
					RANGE BETWEEN '1 hour'::interval PRECEDING AND CURRENT ROW
				)::smallint events
			FROM (select * from landings union select * from takeoffs) e
			where "time" >= date_trunc('day', startdate::timestamp) at time zone 'Europe/Paris' + '30 minutes'::interval
			and  "time" < date_trunc('day', enddate::timestamp) at time zone 'Europe/Paris'  + '30 minutes'::interval
			) p
	)
select "peak_hour", a."events"
from Cte a
where rnmax=1
order by events desc, peak_hour desc
$$;


ALTER FUNCTION public.peak_hour_all(startdate timestamp with time zone, enddate timestamp with time zone) OWNER TO dump1090;

--
-- TOC entry 4819 (class 0 OID 0)
-- Dependencies: 1698
-- Name: FUNCTION peak_hour_all(startdate timestamp with time zone, enddate timestamp with time zone); Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON FUNCTION public.peak_hour_all(startdate timestamp with time zone, enddate timestamp with time zone) IS 'Compute midpoint and count of all events of the (latest) peak hour for each date of a date range (provide timestamp at ''Europe/Paris'')';


--
-- TOC entry 1700 (class 1255 OID 43040)
-- Name: peak_hour_landings(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.peak_hour_landings(startdate timestamp with time zone DEFAULT CURRENT_DATE, enddate timestamp with time zone DEFAULT (CURRENT_DATE + '1 day'::interval)) RETURNS SETOF public.peak_hour_type
    LANGUAGE sql STABLE
    AS $$
-- https://blog.jooq.org/2016/10/31/a-little-known-sql-feature-use-logical-windowing-to-aggregate-sliding-ranges/
-- https://stackoverflow.com/questions/31345344/sql-query-find-daily-min-max-and-times-when-the-min-and-max-values-occurred

with cte as (
	select
		p."peak_hour",
		p."events",
		row_number() over (partition by date(p.peak_hour at time zone 'Europe/Paris') order by p."events" desc, p.peak_hour desc) rnmax
		from
			(select
				date_trunc('m', "time" - '30 minutes'::interval) peak_hour,
				COUNT(*) OVER (
					ORDER BY "time"
					RANGE BETWEEN '1 hour'::interval PRECEDING AND CURRENT ROW
				)::smallint events
			FROM landings
			where "time" >= date_trunc('day', startdate::timestamp) at time zone 'Europe/Paris' + '30 minutes'::interval
			and  "time" < date_trunc('day', enddate::timestamp) at time zone 'Europe/Paris'  + '30 minutes'::interval
			) p
	)
select "peak_hour", a."events"
from Cte a
where rnmax=1
order by events desc, peak_hour desc
$$;


ALTER FUNCTION public.peak_hour_landings(startdate timestamp with time zone, enddate timestamp with time zone) OWNER TO dump1090;

--
-- TOC entry 4820 (class 0 OID 0)
-- Dependencies: 1700
-- Name: FUNCTION peak_hour_landings(startdate timestamp with time zone, enddate timestamp with time zone); Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON FUNCTION public.peak_hour_landings(startdate timestamp with time zone, enddate timestamp with time zone) IS 'Compute midpoint and landings count of the (latest) peak hour for each date of a date range (provide timestamp at ''Europe/Paris'')';


--
-- TOC entry 1699 (class 1255 OID 42794)
-- Name: peak_hour_takeoffs(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.peak_hour_takeoffs(startdate timestamp with time zone DEFAULT CURRENT_DATE, enddate timestamp with time zone DEFAULT (CURRENT_DATE + '1 day'::interval)) RETURNS SETOF public.peak_hour_type
    LANGUAGE sql STABLE
    AS $$
-- https://blog.jooq.org/2016/10/31/a-little-known-sql-feature-use-logical-windowing-to-aggregate-sliding-ranges/
-- https://stackoverflow.com/questions/31345344/sql-query-find-daily-min-max-and-times-when-the-min-and-max-values-occurred

with cte as (
	select
		p."peak_hour",
		p."events",
		row_number() over (partition by date(p.peak_hour at time zone 'Europe/Paris') order by p."events" desc, p.peak_hour desc) rnmax
		from
			(select
				date_trunc('m', "time" - '30 minutes'::interval) peak_hour,
				COUNT(*) OVER (
					ORDER BY "time"
					RANGE BETWEEN '1 hour'::interval PRECEDING AND CURRENT ROW
				)::smallint events
			FROM takeoffs
			where "time" >= date_trunc('day', startdate::timestamp) at time zone 'Europe/Paris' + '30 minutes'::interval
			and  "time" < date_trunc('day', enddate::timestamp) at time zone 'Europe/Paris'  + '30 minutes'::interval
			) p
	)
select "peak_hour", a."events"
from Cte a
where rnmax=1
order by events desc, peak_hour desc
$$;


ALTER FUNCTION public.peak_hour_takeoffs(startdate timestamp with time zone, enddate timestamp with time zone) OWNER TO dump1090;

--
-- TOC entry 4821 (class 0 OID 0)
-- Dependencies: 1699
-- Name: FUNCTION peak_hour_takeoffs(startdate timestamp with time zone, enddate timestamp with time zone); Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON FUNCTION public.peak_hour_takeoffs(startdate timestamp with time zone, enddate timestamp with time zone) IS 'Compute midpoint and landings count of the (latest) peak hour for each date of a date range (provide timestamp at ''Europe/Paris'')';


--
-- TOC entry 1690 (class 1255 OID 41729)
-- Name: takeoffs_histogram(timestamp with time zone, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.takeoffs_histogram(starts timestamp with time zone DEFAULT CURRENT_DATE, ends timestamp with time zone DEFAULT (CURRENT_DATE + '1 day'::interval), bin text DEFAULT 'hour'::text) RETURNS SETOF public.events_histogram_type
    LANGUAGE sql STABLE
    AS $$
SELECT t1."interval" as "time",
       t2.events,
	   flight_ids
FROM   (SELECT "interval" at time zone 'Europe/Paris' as "interval"
        FROM   generate_series(date_trunc(bin, starts::date)::timestamp, date_trunc(bin, ends::date)::timestamp, CONCAT('1 ', bin)::interval) AS "interval") t1
       LEFT OUTER JOIN (SELECT date_trunc(bin, "time" at time zone 'Europe/Paris') at time zone 'Europe/Paris' as "interval",
                               COUNT(flight_id) events,
							   array_agg(flight_id) as flight_ids
                        FROM   takeoffs
                        GROUP  BY "interval") t2
                    ON t1."interval" = t2."interval"
ORDER BY "time" ASC;
$$;


ALTER FUNCTION public.takeoffs_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text) OWNER TO dump1090;

--
-- TOC entry 213 (class 1259 OID 29046)
-- Name: takeoffs; Type: TABLE; Schema: public; Owner: dump1090
--

CREATE TABLE public.takeoffs (
    id integer NOT NULL,
    flight_id integer,
    "time" timestamp(6) with time zone NOT NULL,
    runway character varying(3) NOT NULL
);


ALTER TABLE public.takeoffs OWNER TO dump1090;

--
-- TOC entry 1694 (class 1255 OID 37235)
-- Name: takeoffs_on(date); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.takeoffs_on(mydate date DEFAULT CURRENT_DATE) RETURNS SETOF public.takeoffs
    LANGUAGE sql STABLE
    AS $$SELECT * FROM takeoffs
	WHERE takeoffs.time >= mydate
	AND takeoffs.time < (mydate + 1)
	ORDER BY takeoffs.time asc;$$;


ALTER FUNCTION public.takeoffs_on(mydate date) OWNER TO dump1090;

--
-- TOC entry 286 (class 1259 OID 31225)
-- Name: flights; Type: TABLE; Schema: public; Owner: dump1090
--

CREATE TABLE public.flights (
    id integer NOT NULL,
    hexident character varying(6) NOT NULL,
    callsign character varying(10),
    first_seen timestamp(6) with time zone NOT NULL,
    last_seen timestamp(6) with time zone,
    intention character varying(9)
);


ALTER TABLE public.flights OWNER TO dump1090;

--
-- TOC entry 209 (class 1259 OID 29037)
-- Name: flights_id_seq; Type: SEQUENCE; Schema: public; Owner: dump1090
--

CREATE SEQUENCE public.flights_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flights_id_seq OWNER TO dump1090;

--
-- TOC entry 4826 (class 0 OID 0)
-- Dependencies: 209
-- Name: flights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.flights_id_seq OWNED BY public.flights.id;


--
-- TOC entry 211 (class 1259 OID 29042)
-- Name: landings_id_seq; Type: SEQUENCE; Schema: public; Owner: dump1090
--

CREATE SEQUENCE public.landings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.landings_id_seq OWNER TO dump1090;

--
-- TOC entry 4827 (class 0 OID 0)
-- Dependencies: 211
-- Name: landings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.landings_id_seq OWNED BY public.landings.id;


--
-- TOC entry 287 (class 1259 OID 31231)
-- Name: positions; Type: TABLE; Schema: public; Owner: dump1090
--

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

--
-- TOC entry 212 (class 1259 OID 29044)
-- Name: positions_id_seq; Type: SEQUENCE; Schema: public; Owner: dump1090
--

CREATE SEQUENCE public.positions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.positions_id_seq OWNER TO dump1090;

--
-- TOC entry 4829 (class 0 OID 0)
-- Dependencies: 212
-- Name: positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.positions_id_seq OWNED BY public.positions.id;


--
-- TOC entry 297 (class 1259 OID 34332)
-- Name: positions_live; Type: TABLE; Schema: public; Owner: dump1090
--

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

--
-- TOC entry 214 (class 1259 OID 29049)
-- Name: takeoffs_id_seq; Type: SEQUENCE; Schema: public; Owner: dump1090
--

CREATE SEQUENCE public.takeoffs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.takeoffs_id_seq OWNER TO dump1090;

--
-- TOC entry 4831 (class 0 OID 0)
-- Dependencies: 214
-- Name: takeoffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.takeoffs_id_seq OWNED BY public.takeoffs.id;


--
-- TOC entry 4643 (class 2604 OID 31237)
-- Name: flights id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.flights ALTER COLUMN id SET DEFAULT nextval('public.flights_id_seq'::regclass);


--
-- TOC entry 4641 (class 2604 OID 31238)
-- Name: landings id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.landings ALTER COLUMN id SET DEFAULT nextval('public.landings_id_seq'::regclass);


--
-- TOC entry 4644 (class 2604 OID 31239)
-- Name: positions id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions ALTER COLUMN id SET DEFAULT nextval('public.positions_id_seq'::regclass);


--
-- TOC entry 4642 (class 2604 OID 31240)
-- Name: takeoffs id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.takeoffs ALTER COLUMN id SET DEFAULT nextval('public.takeoffs_id_seq'::regclass);


--
-- TOC entry 4652 (class 2606 OID 31255)
-- Name: flights flights_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.flights
    ADD CONSTRAINT flights_pkey PRIMARY KEY (id);


--
-- TOC entry 4647 (class 2606 OID 29054)
-- Name: landings landings_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.landings
    ADD CONSTRAINT landings_pkey PRIMARY KEY (id);


--
-- TOC entry 4657 (class 2606 OID 31257)
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- TOC entry 4650 (class 2606 OID 29056)
-- Name: takeoffs takeoffs_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.takeoffs
    ADD CONSTRAINT takeoffs_pkey PRIMARY KEY (id);


--
-- TOC entry 4653 (class 1259 OID 41120)
-- Name: idx_flights_first_seen; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_flights_first_seen ON public.flights USING btree (first_seen DESC NULLS LAST);


--
-- TOC entry 4654 (class 1259 OID 41119)
-- Name: idx_flights_id; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE UNIQUE INDEX idx_flights_id ON public.flights USING btree (id DESC NULLS LAST);


--
-- TOC entry 4645 (class 1259 OID 41124)
-- Name: idx_landings_time; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_landings_time ON public.landings USING btree ("time" DESC NULLS LAST);


--
-- TOC entry 4655 (class 1259 OID 47715)
-- Name: idx_positions_flight_id; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_positions_flight_id ON public.positions USING btree (flight_id DESC NULLS LAST);

ALTER TABLE public.positions CLUSTER ON idx_positions_flight_id;


--
-- TOC entry 4658 (class 1259 OID 41134)
-- Name: idx_positions_live_flight_id; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_positions_live_flight_id ON public.positions_live USING btree (flight_id DESC NULLS LAST);

ALTER TABLE public.positions_live CLUSTER ON idx_positions_live_flight_id;


--
-- TOC entry 4659 (class 1259 OID 34346)
-- Name: idx_postitions_live_time; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_postitions_live_time ON public.positions_live USING btree ("time" DESC NULLS LAST);


--
-- TOC entry 4648 (class 1259 OID 41123)
-- Name: idx_takeoffs_time; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_takeoffs_time ON public.takeoffs USING btree ("time" DESC NULLS LAST);


--
-- TOC entry 4792 (class 2618 OID 34344)
-- Name: flights clean_positions_live; Type: RULE; Schema: public; Owner: dump1090
--

CREATE RULE clean_positions_live AS
    ON INSERT TO public.flights DO  DELETE FROM public.positions_live
  WHERE (positions_live."time" < (now() - '1 day'::interval));


--
-- TOC entry 4832 (class 0 OID 0)
-- Dependencies: 4792
-- Name: RULE clean_positions_live ON flights; Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON RULE clean_positions_live ON public.flights IS 'Deletes records in positions_live table which are older than NOW minus 1day';


--
-- TOC entry 4793 (class 2618 OID 34345)
-- Name: positions copy_to_live; Type: RULE; Schema: public; Owner: dump1090
--

CREATE RULE copy_to_live AS
    ON INSERT TO public.positions DO  INSERT INTO public.positions_live (id, flight_id, "time", coordinates, verticalrate, track, onground)  SELECT new.id,
            new.flight_id,
            new."time",
            new.coordinates,
            new.verticalrate,
            new.track,
            new.onground;


--
-- TOC entry 4833 (class 0 OID 0)
-- Dependencies: 4793
-- Name: RULE copy_to_live ON positions; Type: COMMENT; Schema: public; Owner: dump1090
--

COMMENT ON RULE copy_to_live ON public.positions IS 'Copies a new position record to positions_live table on insert.';


--
-- TOC entry 4660 (class 2606 OID 33834)
-- Name: landings landings_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.landings
    ADD CONSTRAINT landings_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4662 (class 2606 OID 31313)
-- Name: positions positions_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4663 (class 2606 OID 34339)
-- Name: positions_live positions_live_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions_live
    ADD CONSTRAINT positions_live_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4661 (class 2606 OID 33829)
-- Name: takeoffs takeoffs_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.takeoffs
    ADD CONSTRAINT takeoffs_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4803 (class 0 OID 0)
-- Dependencies: 4802
-- Name: DATABASE dump1090; Type: ACL; Schema: -; Owner: dump1090
--

GRANT CREATE,CONNECT ON DATABASE dump1090 TO graphql;


--
-- TOC entry 4806 (class 0 OID 0)
-- Dependencies: 19
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: dump1090
--

REVOKE ALL ON SCHEMA public FROM postgres;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO dump1090;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO graphql;


--
-- TOC entry 4808 (class 0 OID 0)
-- Dependencies: 2319
-- Name: TYPE events_histogram_type; Type: ACL; Schema: public; Owner: dump1090
--

GRANT ALL ON TYPE public.events_histogram_type TO graphql;


--
-- TOC entry 4810 (class 0 OID 0)
-- Dependencies: 2322
-- Name: TYPE peak_hour_type; Type: ACL; Schema: public; Owner: dump1090
--

GRANT ALL ON TYPE public.peak_hour_type TO graphql;


--
-- TOC entry 4811 (class 0 OID 0)
-- Dependencies: 1692
-- Name: FUNCTION events_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text); Type: ACL; Schema: public; Owner: dump1090
--

GRANT ALL ON FUNCTION public.events_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text) TO graphql;


--
-- TOC entry 4812 (class 0 OID 0)
-- Dependencies: 1695
-- Name: FUNCTION flight_path(flight_id bigint); Type: ACL; Schema: public; Owner: dump1090
--

GRANT ALL ON FUNCTION public.flight_path(flight_id bigint) TO graphql;


--
-- TOC entry 4813 (class 0 OID 0)
-- Dependencies: 1696
-- Name: FUNCTION flight_path_geojson(flight_id bigint); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.flight_path_geojson(flight_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.flight_path_geojson(flight_id bigint) TO graphql;


--
-- TOC entry 4815 (class 0 OID 0)
-- Dependencies: 1686
-- Name: FUNCTION landings_hist_on(mydate date); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.landings_hist_on(mydate date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.landings_hist_on(mydate date) TO graphql;


--
-- TOC entry 4816 (class 0 OID 0)
-- Dependencies: 1697
-- Name: FUNCTION landings_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text); Type: ACL; Schema: public; Owner: dump1090
--

GRANT ALL ON FUNCTION public.landings_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text) TO graphql;


--
-- TOC entry 4817 (class 0 OID 0)
-- Dependencies: 210
-- Name: TABLE landings; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.landings TO graphql;


--
-- TOC entry 4818 (class 0 OID 0)
-- Dependencies: 1693
-- Name: FUNCTION landings_on(mydate date); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.landings_on(mydate date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.landings_on(mydate date) TO graphql;


--
-- TOC entry 4822 (class 0 OID 0)
-- Dependencies: 1690
-- Name: FUNCTION takeoffs_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text); Type: ACL; Schema: public; Owner: dump1090
--

GRANT ALL ON FUNCTION public.takeoffs_histogram(starts timestamp with time zone, ends timestamp with time zone, bin text) TO graphql;


--
-- TOC entry 4823 (class 0 OID 0)
-- Dependencies: 213
-- Name: TABLE takeoffs; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.takeoffs TO graphql;


--
-- TOC entry 4824 (class 0 OID 0)
-- Dependencies: 1694
-- Name: FUNCTION takeoffs_on(mydate date); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.takeoffs_on(mydate date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.takeoffs_on(mydate date) TO graphql;


--
-- TOC entry 4825 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE flights; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.flights TO graphql;


--
-- TOC entry 4828 (class 0 OID 0)
-- Dependencies: 287
-- Name: TABLE positions; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.positions TO graphql;


--
-- TOC entry 4830 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE positions_live; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.positions_live TO graphql;


-- Completed on 2021-08-01 13:08:00 UTC

--
-- PostgreSQL database dump complete
--

