-- Delete duplicate landing events
DELETE FROM
    landings a
        USING landings b
WHERE
    a.id < b.id
    AND a.flight_id = b.flight_id;


-- Delete duplicate takeoff events
DELETE FROM
    takeoff a
        USING takeoff b
WHERE
    a.id < b.id
    AND a.flight_id = b.flight_id;