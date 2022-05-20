--- Supporting functions ---------------------------

CREATE OR REPLACE FUNCTION public.takeoffs_fromto(
	from_ date,
	to_ date)
    RETURNS SETOF takeoffs
    LANGUAGE 'sql'

    COST 100
    STABLE
    ROWS 2000
AS $BODY$
SELECT * FROM takeoffs as event
	WHERE event.time at time zone 'Europe/Paris' >= from_::date
	AND event.time at time zone 'Europe/Paris' < to_::date
	ORDER BY event.time asc;
$BODY$;

ALTER FUNCTION public.takeoffs_fromto(date, date)
    OWNER TO dump1090;
GRANT EXECUTE ON FUNCTION public.takeoffs_fromto(date, date) TO dump1090;
GRANT EXECUTE ON FUNCTION public.takeoffs_fromto(date, date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.takeoffs_fromto(date, date) TO qgis;


CREATE OR REPLACE FUNCTION public.landings_fromto(
	from_ date,
	to_ date)
    RETURNS SETOF landings
    LANGUAGE 'sql'

    COST 100
    STABLE
    ROWS 2000
AS $BODY$
SELECT * FROM landings as event
	WHERE event.time at time zone 'Europe/Paris' >= from_::date
	AND event.time at time zone 'Europe/Paris' < to_::date
	ORDER BY event.time asc;
$BODY$;

ALTER FUNCTION public.landings_fromto(date, date)
    OWNER TO dump1090;
GRANT EXECUTE ON FUNCTION public.landings_fromto(date, date) TO dump1090;
GRANT EXECUTE ON FUNCTION public.landings_fromto(date, date) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.landings_fromto(date, date) TO qgis;


--- Views ---------------------------------------------

CREATE MATERIALIZED VIEW public.takeoff_paths_currentmonth
 AS
 SELECT distinct flight_id,
    "time",
    runway,
    flight_path(takeoffs_fromto.flight_id::bigint) AS geom
   FROM takeoffs_fromto(date_trunc('MONTH',now())::DATE, now()::DATE+1)

CREATE INDEX gist_idx
    ON public.takeoff_paths_currentmonth_gist_idx USING gist
    (geom)
    TABLESPACE pg_default;


CREATE MATERIALIZED VIEW public.takeoff_paths_currentweek
 AS
 SELECT distinct flight_id,
    "time",
    runway,
    flight_path(takeoffs_fromto.flight_id::bigint) AS geom
   FROM takeoffs_fromto(date_trunc('WEEK',now())::DATE, now()::DATE+1)

CREATE INDEX gist_idx
    ON public.takeoff_paths_currentweek_gist_idx USING gist
    (geom)
    TABLESPACE pg_default;