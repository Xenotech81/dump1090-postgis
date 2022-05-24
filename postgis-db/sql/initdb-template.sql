
REVOKE ALL ON SCHEMA public FROM PUBLIC;


CREATE SCHEMA meta
    AUTHORIZATION postgres;
GRANT USAGE ON SCHEMA meta TO graphql;
GRANT USAGE ON SCHEMA meta TO dump1090;


-- Tie in the shared DB as Foreign Fata Wrapper
CREATE EXTENSION postgres_fdw
    SCHEMA meta
    VERSION "1.1";

CREATE FOREIGN DATA WRAPPER "shared"
    VALIDATOR meta.postgres_fdw_validator
    HANDLER meta.postgres_fdw_handler;
GRANT USAGE ON FOREIGN DATA WRAPPER "shared" TO dump1090;
GRANT USAGE ON FOREIGN DATA WRAPPER "shared" TO graphql;

CREATE SERVER shareddb
    FOREIGN DATA WRAPPER "shared"
    OPTIONS (host 'localhost', port '5432', dbname 'shared', extensions 'postgis');
GRANT USAGE ON FOREIGN SERVER shareddb TO dump1090;
GRANT USAGE ON FOREIGN SERVER shareddb TO graphql;

CREATE USER MAPPING FOR dump1090 SERVER shareddb;
CREATE USER MAPPING FOR graphql SERVER shareddb;
CREATE USER MAPPING FOR postgres SERVER shareddb;

-- Problem: At this point, the server is not running yet, thus the connection
-- is refused!
-- IMPORT FOREIGN SCHEMA public
--	LIMIT TO (aircraft, airlines, airports, countries, runways)
--  FROM SERVER shareddb
--  INTO meta;

