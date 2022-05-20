CREATE ROLE dump1090 WITH
  LOGIN
  NOSUPERUSER
  INHERIT
  CREATEDB
  CREATEROLE
  REPLICATION
  ENCRYPTED PASSWORD 'md5a0ad17ed7a9d37ede8edf61a6f61a91b';
COMMENT ON ROLE dump1090 IS 'Login for dump1090-postgis service.';

CREATE ROLE graphql WITH
  LOGIN
  NOSUPERUSER
  INHERIT
  NOCREATEDB
  NOCREATEROLE
  NOREPLICATION
  ENCRYPTED PASSWORD 'md541d3d6cc2826276118ec2d372fa4c709';
COMMENT ON ROLE graphql IS 'React frontend user with read-only rights';

--  Create the actual database and assign to dump1090 user
CREATE DATABASE dump1090
    WITH
    OWNER = dump1090
    ENCODING = 'UTF8'
    CONNECTION LIMIT = 10;

GRANT CREATE, CONNECT ON DATABASE dump1090 TO graphql;

CREATE SCHEMA public;
ALTER SCHEMA public OWNER TO dump1090;

-- Revoke privileges from PUBLIC default role to prevent its inheritance
REVOKE ALL ON DATABASE dump1090 FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE postgres FROM PUBLIC;

-- Create PostGis extension (in public schema by default)
CREATE EXTENSION postgis;
