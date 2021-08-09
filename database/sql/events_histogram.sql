/* SQL function to create data for an events histogram.

To plot a histogram (barplot) of number of laning and takeoff events per hour/day/week/month/year (=bin) the landing and
takeoff events in the database must be binned accordingly. Providing a start date, end date and bin size,
the function events_histogram() returns a set of records of type 'events_histogram_type', which contains 3 columns:
Date/time of the bin, events count in that bin, array of flight_ids of all events contained in this bin. The contents
of the last column can be used for a second query to retrieve details on each flight.

Query with:
select date AT TIME ZONE 'CEST', events from events_histogram(
    TIMESTAMP '2021-06-01' AT TIME ZONE 'CEST',
    IMESTAMP '2021-06-01' AT TIME ZONE 'CEST',
    'hour')

*/

--DROP FUNCTION events_histogram(date,date,text);
--DROP TYPE public.events_histogram_type;


-- Type: events_histogram_type
CREATE TYPE public.events_histogram_type AS
(
	date timestamp with time zone,
	events bigint,
	flight_ids integer[]
);
ALTER TYPE public.events_histogram_type
    OWNER TO dump1090;
COMMENT ON TYPE public.events_histogram_type
    IS 'Record type for event histogram data: date or time, Nr of events, array of flight_ids';
GRANT USAGE ON TYPE public.events_histogram_type TO PUBLIC;
GRANT USAGE ON TYPE public.events_histogram_type TO dump1090;
GRANT USAGE ON TYPE public.events_histogram_type TO graphql;


-- FUNCTION: public.events_histogram(date, date, text)
--- https://stackoverflow.com/questions/36024712/how-to-group-by-week-in-postgresql

CREATE OR REPLACE FUNCTION public.events_histogram(IN starts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_DATE, IN "ends" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_DATE, IN bin text DEFAULT 'hour')
    RETURNS SETOF events_histogram_type
    LANGUAGE 'sql'
    STABLE
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.events_histogram
    OWNER TO dump1090;
GRANT EXECUTE ON FUNCTION public.events_histogram TO dump1090;
GRANT EXECUTE ON FUNCTION public.events_histogram TO graphql;