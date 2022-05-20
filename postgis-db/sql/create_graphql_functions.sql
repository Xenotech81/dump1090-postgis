-- Types first

CREATE TYPE public.event AS
(
	id integer,
	flight_id integer,
	callsign character(10),
	airline text,
	country text,
	country_code character(2),
	first_seen timestamp(6) with time zone,
	last_seen timestamp(6) with time zone,
	"time" timestamp(6) with time zone,
	runway character(3)
);

ALTER TYPE public.event
    OWNER TO dump1090;

COMMENT ON TYPE public.event
    IS 'Detailed landing or takeoff event';

GRANT USAGE ON TYPE public.event TO PUBLIC;
GRANT USAGE ON TYPE public.event TO dump1090;
GRANT USAGE ON TYPE public.event TO graphql;


-- Functions

CREATE OR REPLACE FUNCTION public.takeoffs_on_details(
	mydate date DEFAULT CURRENT_DATE)
    RETURNS SETOF event
    LANGUAGE 'sql'

    COST 100
    STABLE
    ROWS 1000
AS $BODY$
SELECT
	e.id,
	e.flight_id,
	f.callsign,
	a.name,
	a.country,
	c.code,
	f.first_seen,
	f.last_seen,
	e."time",
	e.runway
	FROM
		(SELECT * FROM takeoffs_on(mydate)) e
		join flights f on e.flight_id = f.id
		left join meta.airlines a on a.icao = SUBSTRING (f.callsign, 1, 3)
		left join meta.countries c on a.country = c.name

$BODY$;

ALTER FUNCTION public.takeoffs_on_details(date)
    OWNER TO dump1090;

GRANT EXECUTE ON FUNCTION public.takeoffs_on_details(date) TO dump1090;

GRANT EXECUTE ON FUNCTION public.takeoffs_on_details(date) TO graphql;

GRANT EXECUTE ON FUNCTION public.takeoffs_on_details(date) TO PUBLIC;



CREATE OR REPLACE FUNCTION public.landings_on_details(
	mydate date DEFAULT CURRENT_DATE)
    RETURNS SETOF event
    LANGUAGE 'sql'

    COST 100
    STABLE
    ROWS 1000
AS $BODY$
SELECT
	e.id,
	e.flight_id,
	f.callsign,
	a.name,
	a.country,
	c.code,
	f.first_seen,
	f.last_seen,
	e."time",
	e.runway
	FROM
		(SELECT * FROM landings_on(mydate)) e
		join flights f on e.flight_id = f.id
		left join meta.airlines a on a.icao = SUBSTRING (f.callsign, 1, 3)
		left join meta.countries c on a.country = c.name

$BODY$;

ALTER FUNCTION public.landings_on_details(date)
    OWNER TO dump1090;

GRANT EXECUTE ON FUNCTION public.landings_on_details(date) TO dump1090;

GRANT EXECUTE ON FUNCTION public.landings_on_details(date) TO graphql;

GRANT EXECUTE ON FUNCTION public.landings_on_details(date) TO PUBLIC;