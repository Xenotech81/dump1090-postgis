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

-- Create PostGis extension before creating the actual database
CREATE EXTENSION postgis;
ALTER EXTENSION postgis UPDATE;

--  Create the actual database and assign to dump1090 user
CREATE DATABASE dump1090
    WITH
    OWNER = dump1090
    ENCODING = 'UTF8'
    CONNECTION LIMIT = 10;

GRANT CREATE, CONNECT ON DATABASE dump1090 TO graphql;