-- Create link table
DROP TABLE IF EXISTS maestro.noise_flight_ids;

CREATE TABLE maestro.noise_flight_ids (
    id BIGSERIAL PRIMARY KEY,
    noise_id BIGINT NOT NULL,
    flight_id BIGINT,
    CONSTRAINT noise_flight_ids_noise_fk
        FOREIGN KEY (noise_id) REFERENCES maestro.noise_measurements(id) ON DELETE CASCADE,
    CONSTRAINT noise_flight_ids_flight_fk
        FOREIGN KEY (flight_id) REFERENCES public.flights(id) ON DELETE CASCADE
);


-- Fill table in batches (for time frames)
INSERT INTO maestro.noise_flight_ids (noise_id, flight_id)
SELECT
    nm.id,
    maestro.flight_id_of_noise(nm.campaign, nm.maxts_local) AS flight_id
FROM maestro.noise_measurements nm
WHERE (nm.maxts_local AT TIME ZONE 'Europe/Paris')::date BETWEEN (DATE '2024-07-01'AT TIME ZONE 'Europe/Paris') AND (DATE '2024-10-31'AT TIME ZONE 'Europe/Paris');


-- Once the link table has been created, the view linking the noise_measurements
-- and flight data goes very fast
CREATE OR REPLACE VIEW maestro.v_noise_flights AS
SELECT
    nm.id AS noise_measurement_id,
    nm.campaign,
	s.name,
    nm.maxts_local,
    nm.type_avion,
    nm.duration_s,
    nm.direction,
    nm.alt_m,
    nm.laeq,
    nm.sel,
    nm.lamax1s,
    f.id AS flight_id,
    f.hexident,
    f.callsign,
    a.name AS airline
FROM maestro.noise_measurements nm
JOIN maestro.noise_flight_ids nfid
       ON nfid.noise_id = nm.id
JOIN maestro.stations s
       ON nm.campaign = s.campaign
LEFT JOIN public.flights f
       ON f.id = nfid.flight_id
LEFT JOIN meta.airlines a
       ON a.icao = NULLIF(SUBSTRING(f.callsign, 1, 3), '')