CREATE TABLE meta.airlines (
	id SERIAL,
	alias VARCHAR(50),
	iata VARCHAR(10),
	icao VARCHAR(10),
	callsign VARCHAR(50),
	country VARCHAR(50),
	active VARCHAR(1),
	PRIMARY KEY (id)
)

CREATE TABLE meta.aircraft (
  id SERIAL,
  model CHARACTER VARYING(20) NOT NULL,
  silhouette BYTEA NOT NULL,
  PRIMARY Key(id));

CREATE INDEX model_idx
    ON meta.aircraft USING btree
    (model ASC NULLS LAST)
    TABLESPACE pg_default;

/* https://stackoverflow.com/questions/18533625/copy-multiple-csv-files-into-postgres*/
CREATE FUNCTION meta.load_aircraft(dir text DEFAULT '/database/silhouettes/')
    RETURNS integer as $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN select pg_ls_dir(dir) AS fn LOOP
	RAISE NOTICE 'Loading aircraft silhouette BMPs...';
	IF (rec.fn ~ '.bmp$') THEN
	  INSERT INTO meta.aircraft (model, silhouette)  VALUES (split_part(rec.fn, '.', 1), pg_read_binary_file(dir || rec.fn));
	END IF;
END LOOP;
RAISE NOTICE 'Done';
RETURN 1;
END;
$$ LANGUAGE plpgsql;

INSERT INTO meta.aircraft (id, model, silhouette)  VALUES (2, split_part('A321.bmp', '.', 1), pg_read_binary_file('/database/A321.bmp'));

FOR filename IN select pg_ls_dir(directory) LOOP
	RAISE NOTICE 'Loading aircraft silhouette BMPs...';
	IF (filename ~ '.bmp$') THEN
	  INSERT INTO meta.aircraft (id, model, silhouette)  VALUES (2, split_part(filename, '.', 1), pg_read_binary_file(filename));
	END IF;
END LOOP;
RAISE NOTICE 'Done';
RETURN 1;