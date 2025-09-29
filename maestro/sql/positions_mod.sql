-- Time index, optimized for chronological records, creation time ~20min
CREATE INDEX CONCURRENTLY positions_time_brin ON positions
  USING BRIN (time) WITH (pages_per_range = 128);

-- SP-GIST spatial index, optimized for Points, creation time ~12h
-- Use queries with ST_Transform(positions.coordinates, 2154)
CREATE INDEX CONCURRENTLY positions_coordinates_2154_spgist
  ON positions
  USING spgist (ST_Transform(coordinates, 2154))
  WHERE coordinates IS NOT NULL;
