--
-- PostgreSQL database dump
--

-- Dumped from database version 11.2 (Debian 11.2-1.pgdg90+1)
-- Dumped by pg_dump version 12.0

-- Started on 2021-06-09 08:30:23 UTC

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
-- TOC entry 18 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: dump1090
--

-- A public schema must exist with the postgis extension at this point!
-- CREATE SCHEMA public;
-- ALTER SCHEMA public OWNER TO dump1090;

--
-- TOC entry 2064 (class 1247 OID 29028)
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
-- TOC entry 1677 (class 1255 OID 33762)
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
-- TOC entry 1682 (class 1255 OID 33686)
-- Name: flight_path_today(bigint); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.flight_path_today(flight_id bigint) RETURNS public.geometry
    LANGUAGE plpgsql STABLE
    AS $$BEGIN
	RETURN st_makeline(st_force2d(p.coordinates) ORDER BY p.time) FROM flights f
	JOIN public.positions_live p on f.id = p.flight_id
	WHERE f.id = flight_path_today.flight_id;
END$$;


ALTER FUNCTION public.flight_path_today(flight_id bigint) OWNER TO dump1090;

--
-- TOC entry 1683 (class 1255 OID 39082)
-- Name: flight_path_today_geojson(bigint); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.flight_path_today_geojson(flight_id bigint) RETURNS json
    LANGUAGE plpgsql STABLE
    AS $$BEGIN
	RETURN ST_AsGeoJSON(st_makeline(st_force2d(p.coordinates) ORDER BY p.time)) FROM flights f
	JOIN public.positions_live p on f.id = p.flight_id
	WHERE f.id = flight_path_today_geojson.flight_id;
END$$;


ALTER FUNCTION public.flight_path_today_geojson(flight_id bigint) OWNER TO dump1090;

--
-- TOC entry 1675 (class 1255 OID 39330)
-- Name: flight_paths(bigint[]); Type: FUNCTION; Schema: public; Owner: dump1090
--

CREATE FUNCTION public.flight_paths(flight_ids bigint[]) RETURNS SETOF json
    LANGUAGE plpgsql STABLE
    AS $$declare
flight_id bigint;

begin
	foreach flight_id in array flight_ids loop
		RAISE NOTICE 'Flightid (%)',flight_id;
		return next flight_path_today_geojson(flight_id);
	end loop;
end$$;


ALTER FUNCTION public.flight_paths(flight_ids bigint[]) OWNER TO dump1090;

--
-- TOC entry 1676 (class 1255 OID 37390)
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

SET default_tablespace = '';

--
-- TOC entry 209 (class 1259 OID 29039)
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
-- TOC entry 1680 (class 1255 OID 37234)
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
-- TOC entry 212 (class 1259 OID 29046)
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
-- TOC entry 1681 (class 1255 OID 37235)
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
-- TOC entry 285 (class 1259 OID 31225)
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
-- TOC entry 208 (class 1259 OID 29037)
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
-- TOC entry 4763 (class 0 OID 0)
-- Dependencies: 208
-- Name: flights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.flights_id_seq OWNED BY public.flights.id;


--
-- TOC entry 210 (class 1259 OID 29042)
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
-- TOC entry 4764 (class 0 OID 0)
-- Dependencies: 210
-- Name: landings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.landings_id_seq OWNED BY public.landings.id;


--
-- TOC entry 286 (class 1259 OID 31231)
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
-- TOC entry 211 (class 1259 OID 29044)
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
-- TOC entry 4766 (class 0 OID 0)
-- Dependencies: 211
-- Name: positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.positions_id_seq OWNED BY public.positions.id;


--
-- TOC entry 296 (class 1259 OID 34332)
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
-- TOC entry 213 (class 1259 OID 29049)
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
-- TOC entry 4768 (class 0 OID 0)
-- Dependencies: 213
-- Name: takeoffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dump1090
--

ALTER SEQUENCE public.takeoffs_id_seq OWNED BY public.takeoffs.id;


--
-- TOC entry 4602 (class 2604 OID 31237)
-- Name: flights id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.flights ALTER COLUMN id SET DEFAULT nextval('public.flights_id_seq'::regclass);


--
-- TOC entry 4600 (class 2604 OID 31238)
-- Name: landings id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.landings ALTER COLUMN id SET DEFAULT nextval('public.landings_id_seq'::regclass);


--
-- TOC entry 4603 (class 2604 OID 31239)
-- Name: positions id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions ALTER COLUMN id SET DEFAULT nextval('public.positions_id_seq'::regclass);


--
-- TOC entry 4601 (class 2604 OID 31240)
-- Name: takeoffs id; Type: DEFAULT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.takeoffs ALTER COLUMN id SET DEFAULT nextval('public.takeoffs_id_seq'::regclass);


--
-- TOC entry 4609 (class 2606 OID 31255)
-- Name: flights flights_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.flights
    ADD CONSTRAINT flights_pkey PRIMARY KEY (id);


--
-- TOC entry 4605 (class 2606 OID 29054)
-- Name: landings landings_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.landings
    ADD CONSTRAINT landings_pkey PRIMARY KEY (id);


--
-- TOC entry 4612 (class 2606 OID 31257)
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- TOC entry 4607 (class 2606 OID 29056)
-- Name: takeoffs takeoffs_pkey; Type: CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.takeoffs
    ADD CONSTRAINT takeoffs_pkey PRIMARY KEY (id);


--
-- TOC entry 4613 (class 1259 OID 34338)
-- Name: fki_positions_flight_id_fkey; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX fki_positions_flight_id_fkey ON public.positions_live USING btree (flight_id);


--
-- TOC entry 4610 (class 1259 OID 31259)
-- Name: idx_positions_coordinates; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_positions_coordinates ON public.positions USING gist (coordinates);


--
-- TOC entry 4614 (class 1259 OID 34346)
-- Name: idx_postitions_live_time; Type: INDEX; Schema: public; Owner: dump1090
--

CREATE INDEX idx_postitions_live_time ON public.positions_live USING btree ("time" DESC NULLS LAST);


--
-- TOC entry 4747 (class 2618 OID 34344)
-- Name: flights clean_positions_live; Type: RULE; Schema: public; Owner: dump1090
--

CREATE RULE clean_positions_live AS
    ON INSERT TO public.flights DO  DELETE FROM public.positions_live
  WHERE (positions_live."time" < (now() - '1 day'::interval));


--
-- TOC entry 4748 (class 2618 OID 34345)
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
-- TOC entry 4615 (class 2606 OID 33834)
-- Name: landings landings_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.landings
    ADD CONSTRAINT landings_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4617 (class 2606 OID 31313)
-- Name: positions positions_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4618 (class 2606 OID 34339)
-- Name: positions_live positions_live_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.positions_live
    ADD CONSTRAINT positions_live_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4616 (class 2606 OID 33829)
-- Name: takeoffs takeoffs_flight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dump1090
--

ALTER TABLE ONLY public.takeoffs
    ADD CONSTRAINT takeoffs_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE;


--
-- TOC entry 4754 (class 0 OID 0)
-- Dependencies: 18
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: dump1090
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO dump1090;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO graphql;


--
-- TOC entry 4755 (class 0 OID 0)
-- Dependencies: 1682
-- Name: FUNCTION flight_path_today(flight_id bigint); Type: ACL; Schema: public; Owner: dump1090
--

GRANT ALL ON FUNCTION public.flight_path_today(flight_id bigint) TO graphql;


--
-- TOC entry 4756 (class 0 OID 0)
-- Dependencies: 1683
-- Name: FUNCTION flight_path_today_geojson(flight_id bigint); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.flight_path_today_geojson(flight_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.flight_path_today_geojson(flight_id bigint) TO graphql;


--
-- TOC entry 4757 (class 0 OID 0)
-- Dependencies: 1676
-- Name: FUNCTION landings_hist_on(mydate date); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.landings_hist_on(mydate date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.landings_hist_on(mydate date) TO graphql;


--
-- TOC entry 4758 (class 0 OID 0)
-- Dependencies: 209
-- Name: TABLE landings; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.landings TO graphql;


--
-- TOC entry 4759 (class 0 OID 0)
-- Dependencies: 1680
-- Name: FUNCTION landings_on(mydate date); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.landings_on(mydate date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.landings_on(mydate date) TO graphql;


--
-- TOC entry 4760 (class 0 OID 0)
-- Dependencies: 212
-- Name: TABLE takeoffs; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.takeoffs TO graphql;


--
-- TOC entry 4761 (class 0 OID 0)
-- Dependencies: 1681
-- Name: FUNCTION takeoffs_on(mydate date); Type: ACL; Schema: public; Owner: dump1090
--

REVOKE ALL ON FUNCTION public.takeoffs_on(mydate date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.takeoffs_on(mydate date) TO graphql;


--
-- TOC entry 4762 (class 0 OID 0)
-- Dependencies: 285
-- Name: TABLE flights; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.flights TO graphql;


--
-- TOC entry 4765 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE positions; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.positions TO graphql;


--
-- TOC entry 4767 (class 0 OID 0)
-- Dependencies: 296
-- Name: TABLE positions_live; Type: ACL; Schema: public; Owner: dump1090
--

GRANT SELECT ON TABLE public.positions_live TO graphql;


-- Completed on 2021-06-09 08:30:24 UTC

--
-- PostgreSQL database dump complete
--

