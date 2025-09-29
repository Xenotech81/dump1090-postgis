-- Z(coordinates) is sometimes 0 for flights without ADSB position, so filter them out
-- Z(coordinates) can also be sometimes negative, due to ALT errors, keep them!

DROP FUNCTION IF EXISTS maestro.flight_id_of_noise(text, timestamp without time zone);

CREATE OR REPLACE FUNCTION maestro.flight_id_of_noise(
	in_campaign text,
	in_maxts_local timestamp without time zone)
    RETURNS bigint
    LANGUAGE 'plpgsql'
    COST 100
    STABLE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_flight_id BIGINT;
BEGIN
    SELECT f.id
    INTO v_flight_id
    FROM maestro.stations s
    JOIN public.positions p
      ON ST_DWithin(ST_Transform(p.coordinates, 2154), s.geom, s.range_m)
     AND ST_Z(p.coordinates) < 1400 AND ST_Z(p.coordinates) != 0
     AND p.time BETWEEN (in_maxts_local AT TIME ZONE 'Europe/Paris' - INTERVAL '10 seconds')
                    AND (in_maxts_local AT TIME ZONE 'Europe/Paris' + INTERVAL '10 seconds')
    JOIN public.flights f
      ON f.id = p.flight_id
    WHERE s.campaign = in_campaign
    ORDER BY ST_Distance(ST_Transform(p.coordinates, 2154), s.geom)
    LIMIT 1;

    RETURN v_flight_id; -- will be NULL if no row found
END;
$BODY$;

ALTER FUNCTION maestro.flight_id_of_noise(text, timestamp without time zone)
    OWNER TO dump1090;
