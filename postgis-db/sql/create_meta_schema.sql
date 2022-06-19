--
-- PostgreSQL database dump
--

-- Dumped from database version 11.2 (Debian 11.2-1.pgdg90+1)
-- Dumped by pg_dump version 13.3

-- Started on 2021-07-25 16:55:18 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 18 (class 2615 OID 47429)
-- Name: meta; Type: SCHEMA; Schema: -; Owner: dump1090
--

CREATE SCHEMA meta;


ALTER SCHEMA meta OWNER TO dump1090;

GRANT USAGE ON SCHEMA meta TO graphql;

SET default_tablespace = '';

--
-- TOC entry 300 (class 1259 OID 47430)
-- Name: airports; Type: TABLE; Schema: meta; Owner: dump1090
--

CREATE TABLE meta.airports (
    icao character varying(4) NOT NULL,
    iata character varying(3) NOT NULL,
    name text NOT NULL,
    city text,
    latlon public.geometry NOT NULL,
    bbox public.geometry NOT NULL,
    altitude double precision NOT NULL,
    country text,
    locale text NOT NULL,
    timezone text NOT NULL,
    CONSTRAINT check_valid_bbox CHECK (public.st_isvalid(bbox)),
    CONSTRAINT enforce_srid_4326 CHECK ((public.st_srid(latlon) = 4326))
);


ALTER TABLE meta.airports OWNER TO dump1090;

--
-- TOC entry 4769 (class 0 OID 0)
-- Dependencies: 300
-- Name: TABLE airports; Type: COMMENT; Schema: meta; Owner: dump1090
--

COMMENT ON TABLE meta.airports IS 'Airport definition: Description and geometry (except runways)';


--
-- TOC entry 4770 (class 0 OID 0)
-- Dependencies: 300
-- Name: COLUMN airports.latlon; Type: COMMENT; Schema: meta; Owner: dump1090
--

COMMENT ON COLUMN meta.airports.latlon IS 'Geometry point';


--
-- TOC entry 4771 (class 0 OID 0)
-- Dependencies: 300
-- Name: COLUMN airports.altitude; Type: COMMENT; Schema: meta; Owner: dump1090
--

COMMENT ON COLUMN meta.airports.altitude IS 'Altitude ASL';


--
-- TOC entry 4772 (class 0 OID 0)
-- Dependencies: 300
-- Name: CONSTRAINT check_valid_bbox ON airports; Type: COMMENT; Schema: meta; Owner: dump1090
--

COMMENT ON CONSTRAINT check_valid_bbox ON meta.airports IS 'Allow only valid polygon geometry for bbox';


--
-- TOC entry 4773 (class 0 OID 0)
-- Dependencies: 300
-- Name: CONSTRAINT enforce_srid_4326 ON airports; Type: COMMENT; Schema: meta; Owner: dump1090
--

COMMENT ON CONSTRAINT enforce_srid_4326 ON meta.airports IS 'Allow only 4326 as SRID';


--
-- TOC entry 301 (class 1259 OID 47438)
-- Name: airports_geojson; Type: VIEW; Schema: meta; Owner: dump1090
--

CREATE VIEW meta.airports_geojson AS
 SELECT airports.icao,
    airports.iata,
    airports.name,
    airports.city,
    airports.altitude,
    airports.country,
    airports.locale,
    airports.timezone,
    (public.st_asgeojson(airports.bbox, 6))::json AS bbox,
    (public.st_asgeojson(airports.latlon, 6))::json AS latlon
   FROM meta.airports;


ALTER TABLE meta.airports_geojson OWNER TO dump1090;

--
-- TOC entry 302 (class 1259 OID 47442)
-- Name: airports_id_seq; Type: SEQUENCE; Schema: meta; Owner: dump1090
--

CREATE SEQUENCE meta.airports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 1000
    CACHE 1;


ALTER TABLE meta.airports_id_seq OWNER TO dump1090;

--
-- TOC entry 303 (class 1259 OID 47450)
-- Name: range_rings; Type: TABLE; Schema: meta; Owner: dump1090
--

CREATE TABLE meta.range_rings (
    geom public.geometry(MultiLineString,4326),
    id integer NOT NULL,
    radius double precision,
    icao character varying(4)
);


ALTER TABLE meta.range_rings OWNER TO dump1090;

--
-- TOC entry 304 (class 1259 OID 47458)
-- Name: range_rings_geojson; Type: VIEW; Schema: meta; Owner: dump1090
--

CREATE VIEW meta.range_rings_geojson AS
 SELECT rr.id,
    rr.radius,
    rr.icao,
    (public.st_asgeojson(rr.geom, 6, 2))::json AS geom
   FROM meta.range_rings rr;


ALTER TABLE meta.range_rings_geojson OWNER TO dump1090;

--
-- TOC entry 305 (class 1259 OID 47464)
-- Name: runways; Type: TABLE; Schema: meta; Owner: dump1090
--

CREATE TABLE meta.runways (
    id integer NOT NULL,
    geom public.geometry(Polygon,4326),
    airport_icao character varying(4),
    name character varying(255),
    direction integer,
    length double precision
);


ALTER TABLE meta.runways OWNER TO dump1090;

--
-- TOC entry 306 (class 1259 OID 47470)
-- Name: runways_geojson; Type: VIEW; Schema: meta; Owner: dump1090
--

CREATE VIEW meta.runways_geojson AS
 SELECT rw.id,
    rw.airport_icao,
    rw.name,
    rw.direction,
    rw.length,
    (public.st_asgeojson(rw.geom, 6))::json AS geom
   FROM meta.runways rw;


ALTER TABLE meta.runways_geojson OWNER TO dump1090;

--
-- TOC entry 307 (class 1259 OID 47474)
-- Name: runways_id_0_seq; Type: SEQUENCE; Schema: meta; Owner: dump1090
--

CREATE SEQUENCE meta.runways_id_0_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE meta.runways_id_0_seq OWNER TO dump1090;

--
-- TOC entry 4780 (class 0 OID 0)
-- Dependencies: 307
-- Name: runways_id_0_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: dump1090
--

ALTER SEQUENCE meta.runways_id_0_seq OWNED BY meta.runways.id;


--
-- TOC entry 4617 (class 2604 OID 47478)
-- Name: runways id; Type: DEFAULT; Schema: meta; Owner: dump1090
--

ALTER TABLE ONLY meta.runways ALTER COLUMN id SET DEFAULT nextval('meta.runways_id_0_seq'::regclass);


--
-- TOC entry 4759 (class 0 OID 47430)
-- Dependencies: 300
-- Data for Name: airports; Type: TABLE DATA; Schema: meta; Owner: dump1090
--

COPY meta.airports (icao, iata, name, city, latlon, bbox, altitude, country, locale, timezone) FROM stdin;
LFRS	NTE	Nantes Atlantique Airport	Nantes	0101000020E610000027E5BF166CC1F9BF80F4396DA0934740	0103000020E61000000100000006000000BF6378EC67F1F9BF01F9122A38924740DAA9B9DC60A8F9BFF817416326954740020CCB9F6F8BF9BFF2272A1BD69447402D5F97E13F9DF9BFC366800BB2934740A0FEB3E6C7DFF9BFE04A766C04924740BF6378EC67F1F9BF01F9122A38924740	27	France	fr_FR	Europe/Paris
\.


--
-- TOC entry 4761 (class 0 OID 47450)
-- Dependencies: 303
-- Data for Name: range_rings; Type: TABLE DATA; Schema: meta; Owner: dump1090
--

COPY meta.range_rings (geom, id, radius, icao) FROM stdin;
0105000020E6100000010000000102000000A10000008F80A67BD8C3E6BF7EF4396DA0934740F0428CE784C9E6BF5C36865C8E90474058CAEBED87DAE6BF656E84277D8D47408126B2D7DAF6E6BFB89DC6046E8A47400BCAB176721EE7BF79A7772A62874740A3560C2A3F51E7BF1E41DFCD5A844740D3E35DE42C8FE7BF2997E522598147401D51A73323D8E7BFF4DA965B5E7E47409B83F44A052CE8BF40EFA6A76B7B4740E9BFBA0DB28AE8BF246AF53382784740A4A3EA1C04F4E8BFC823122AA3754740B795B0E5D167E9BFF989C2AFCF724740B6DADDB1EDE5E9BF4DF187E60870474006D3F3B9256EEABFD91C27EB4F6D47407943CA384400EBBFD43531D5A56A4740ADE6C8800F9CEBBF9E6C8EB60B68474067E6AB124A41ECBF827C0A9B826547404440CAB5B2EFECBF874BE3870B6347409F80D49104A7EDBF16DF597BA760474039AA014AF766EEBFE8DD456C575E474057909F193F2FEFBFD3D6AB491C5C47401F5DFBF18CFFEFBF628356FAF6594740D83ACB4CC76BF0BFF53B735CE85747405AB54D6677DBF0BF2CD23145F1554740AE1243AFAA4EF1BFC804688012544740F90379AE33C5F1BFFABE38D04C5247405422C099E33EF2BF2853BFECA0504740851F64688ABBF2BF83DFBE830F4F47409FB121E6F63AF3BFEA085638994D47408FBD92C6F6BCF3BF2936B7A23E4C4740EC1509B95641F4BFC173E54F004B4740A5F7CF7CE2C7F4BFC92576C1DE494740B745CCF56450F5BFF0AA576DDA484740AA5F7341A8DAF5BF39119DBDF3474740434C10CC7566F6BF18FA4E102B4747401FD34E6696F3F6BFCFC841B7804647403104045BD281F7BF0333F1F7F4454740E3932B85F110F8BF7F48610B88454740BB5D1166BBA0F8BFDA03051E3A454740144E9E3BF730F9BFE072AA4F0B4547404FE5BF166CC1F9BFF4816CB3FB444740887CE1F1E051FABFE072AA4F0B454740E06C6EC71CE2FABFDA03051E3A454740BA3654A8E671FBBF7F48610B884547406BC67BD20501FCBF0333F1F7F44547407DF730C7418FFCBFCFC841B780464740597E6F61621CFDBF18FA4E102B474740F36A0CEC2FA8FDBF39119DBDF3474740E584B3377332FEBFF0AA576DDA484740F9D2AFB0F5BAFEBFC92576C1DE494740B1B476748141FFBFC173E54F004B47400E0DED66E1C5FFBF2936B7A23E4C47407E0CAFA3F02300C0EA085638994D47408BD58DE2A66300C083DFBE830F4F474024D4DF49FAA100C02853BFECA05047405163833FD2DE00C0FABE38D04C524740F75B1EBF161A01C0C804688012544740A00A9963B05301C02CD23145F1554740E0475A70888B01C0F53B735CE8574740040E41DA88C101C0628356FAF6594740360158509CF501C0D3D6AB491C5C4740BE7A3F44AE2702C0E8DD456C575E474024C54AF2AA5702C016DF597BA76047403B554D697F8502C0874BE3870B634740B2EB149219B102C0827C0A9B82654740A1AB8D3668DA02C09D6C8EB60B6847406E548D085B0103C0D33531D5A56A47408AF042A8E22503C0D81C27EB4F6D47409E6E48AAF04703C04DF187E608704740DEBF539D776703C0F989C2AFCF724740643C850F6B8403C0C823122AA375474053355193BF9E03C0246AF5338278474066C402C46AB603C03FEFA6A76B7B47400611D64963CB03C0F4DA965B5E7E4740596CA8DDA0DD03C02997E52259814740A6CF3C4C1CED03C01D41DFCD5A844740CD721379CFF903C078A7772A62874740AF5BD360B50304C0B79DC6046E8A4740BAF2441BCA0A04C0656E84277D8D474095D4DCDC0A0F04C05C36865C8E9047402E45D6F7751004C07DF4396DA093474096D4DCDC0A0F04C0521A2223B2964740BCF2441BCA0A04C0536B5048C2994740B45BD360B50304C0E3F9DFA7CF9C4740D2721379CFF903C06C126E0ED99F4740ACCF3C4C1CED03C08DE6914ADDA24740616CA8DDA0DD03C0BDCB522DDBA547400E11D64963CB03C07AE29C8AD1A847406FC402C46AB603C08AFCB339BFAB47405D355193BF9E03C0CB9AA415A3AE4740703C850F6B8403C043DCB2FD7BB14740EBBF539D776703C0673AC7D548B44740AD6E48AAF04703C0C4EFD88608B7474099F042A8E22503C043E855FFB9B947407D548D085B0103C0B41B88335CBC4740B1AB8D3668DA02C04635F81DEEBE4740C4EB149219B102C0E86BCDBF6EC147404D554D697F8502C07B712A21DDC3474037C54AF2AA5702C03160875138C64740D27A3F44AE2702C0348F08687FC847404B0158509CF501C0E638D283B1CA47401A0E41DA88C101C0F2DE58CCCDCC4740F6475A70888B01C08359AE71D3CE4740B60A9963B05301C09180CBACC1D047400C5C1EBF161A01C0565FD6BF97D247406663833FD2DE00C06AE364F654D4474039D4DF49FAA100C046FABBA5F8D54740A1D58DE2A66300C0D6100B2D82D74740940CAFA3F02300C032EAA3F5F0D84740370DED66E1C5FFBF5AC32E7344DA4740DAB476748141FFBFF2BADA237CDB474022D3AFB0F5BAFEBFE4748A9097DC47400E85B3377332FEBF99F2FC4C96DD47401A6B0CEC2FA8FDBF6899F2F777DE4740827E6F61621CFDBF8B614E3B3CDF4740A6F730C7418FFCBFBD2833CCE2DF474092C67BD20501FCBF0F241D6B6BE04740E03654A8E671FBBFAB6DF7E3D5E04740066D6EC71CE2FABF2EAB2D0E22E14740AC7CE1F1E051FABF83CAB9CC4FE1474072E5BF166CC1F9BF1ED32D0E5FE14740384E9E3BF730F9BF83CAB9CC4FE14740DE5D1166BBA0F8BF2FAB2D0E22E1474004942B85F110F8BFAB6DF7E3D5E047405104045BD281F7BF10241D6B6BE047403ED34E6696F3F6BFBD2833CCE2DF4740614C10CC7566F6BF8D614E3B3CDF4740C85F7341A8DAF5BF6899F2F777DE4740D345CCF56450F5BF9AF2FC4C96DD4740BFF7CF7CE2C7F4BFE5748A9097DC4740051609B95641F4BFF3BADA237CDB4740A7BD92C6F6BCF3BF5AC32E7344DA4740B5B121E6F63AF3BF33EAA3F5F0D847409B1F64688ABBF2BFD6100B2D82D747406922C099E33EF2BF46FABBA5F8D547400C0479AE33C5F1BF6BE364F654D44740BF1243AFAA4EF1BF575FD6BF97D247406AB54D6677DBF0BF9380CBACC1D04740E73ACB4CC76BF0BF8459AE71D3CE47403B5DFBF18CFFEFBFF2DE58CCCDCC474070909F193F2FEFBFE838D283B1CA474051AA014AF766EEBF368F08687FC84740B580D49104A7EDBF3260875138C647405640CAB5B2EFECBF7B712A21DDC3474078E6AB124A41ECBFE96BCDBF6EC14740BBE6C8800F9CEBBF4735F81DEEBE47408643CA384400EBBFB61B88335CBC474011D3F3B9256EEABF43E855FFB9B94740BFDADDB1EDE5E9BFC5EFD88608B74740BF95B0E5D167E9BF693AC7D548B44740AAA3EA1C04F4E8BF43DCB2FD7BB14740EDBFBA0DB28AE8BFCC9AA415A3AE47409F83F44A052CE8BF8AFCB339BFAB47401F51A73323D8E7BF7AE29C8AD1A84740D4E35DE42C8FE7BFBECB522DDBA54740A5560C2A3F51E7BF8EE6914ADDA247400BCAB176721EE7BF6D126E0ED99F47408126B2D7DAF6E6BFE3F9DFA7CF9C474058CAEBED87DAE6BF536B5048C2994740F0428CE784C9E6BF521A2223B29647408F80A67BD8C3E6BF7EF4396DA0934740	2	100000	LFRS
0105000020E6100000010000000102000000A1000000CC92492AAC91F2BF7EF4396DA0934740640343451793F2BFE19F3970179247403FE5DA065897F2BFFECDB3F78E904740487C4CC16C9EF2BFEB65BC9E078F47402C650CA952A8F2BF46571000828D47405108E3D505B5F2BFD91CD8B5FE8B47409D6B774481C4F2BFB1506A597E8A4740EFC649D8BED6F2BF976A0E830189474090131D5EB7EBF2BF65C2BFC988874740A2A2CE8E6203F3BF98EFF0C214864740929B9A12B71DF3BFB49F4F02A68447401618CC84AA3AF3BF16FD88193D8347405569D777315AF3BFBABF0E98DA8147406AE7DC793F7CF3BF9701DD0A7F80474087839219C7A0F3BFCFEF40FC2A7F4740532C92EBB9C7F3BF1E72A0F3DE7D474042EC0A9008F1F3BF5FE142759B7C4740B982D2B8A21CF4BF05E61A02617B4740D112D52F774AF4BFD9969117307A4740375DE0DD737AF4BFFFEF522F09794740BFD6C7D185ACF4BFD2B91BBFEC774740F0C9DE4799E0F4BFADF68838DB7647401490C5B19916F5BFFEEDE808D575474056CD86BE714EF5BFB1EA0D99DA744740007C01630B88F5BFEEC1224DEC734740A6749CE24FC3F5BFDB3681840A734740D30340D82700F6BFE04E8A99357247406B02923F7B3EF6BF7EA980E16D71474078CB707E317EF6BF8AED64ACB37047407051A96E31BFF6BF055DD444077047409F7DE4676101F7BF949FE9EF686F47407BEEC749A744F7BFB9D21FEDD86E474085154686E888F7BFD5ED3776576E47407DA2192C0ACEF7BFF08620BFE46D4740CA1868F1F013F8BF1504E0F5806D4740385C873E815AF8BFEF4381422C6D4740C1F4E1389FA1F8BF1BC702C7E66C47409ABCF5CD2EE9F8BF9762489FB06C474086A168BE1331F9BF35820FE1896C4740B3192FA93179F9BFE600E69B726C474050E5BF166CC1F9BF799B23D96A6C4740EDB05084A609FABFE600E69B726C47401A29176FC451FABF35820FE1896C4740050E8A5FA999FABF9762489FB06C4740DFD59DF438E1FABF1BC702C7E66C4740676EF8EE5628FBBFEF4381422C6D4740D5B1173CE76EFBBF1504E0F5806D474021286601CEB4FBBFF08620BFE46D47401BB539A7EFF9FBBFD5ED3776576E474025DCB7E3303EFCBFB9D21FEDD86E4740014D9BC57681FCBF949FE9EF686F47402F79D6BEA6C3FCBF055DD4440770474026FF0EAFA604FDBF8AED64ACB370474034C8EDED5C44FDBF7EA980E16D714740CBC63F55B082FDBFE04E8A9935724740FA55E34A88BFFDBFDB3681840A7347409E4E7ECACCFAFDBFEEC1224DEC7347404AFDF86E6634FEBFB1EA0D99DA744740883ABA7B3E6CFEBFFEEDE808D5754740AD00A1E53EA2FEBFACF68838DB764740DFF3B75B52D6FEBFD2B91BBFEC774740666D9F4F6408FFBFFFEF522F09794740CDB7AAFD6038FFBFD9969117307A4740E447AD743566FFBF05E61A02617B47405BDE749DCF91FFBF5FE142759B7C47404A9EED411EBBFFBF1E72A0F3DE7D47401747ED1311E2FFBFCFEF40FC2A7F47409A71D1594C0300C09701DD0A7F804740A430D45A531400C0BABF0E98DA81474044D959D4162400C016FD88193D8347408797728D903200C0B49F4F02A6844740FE9358CFBA3F00C098EFF0C214864740885BB167904B00C065C2BFC988874740D7019BAA0C5600C0966A0E8301894740812F84742B5F00C0B1506A597E8A47402761CE2BE96600C0D81CD8B5FE8B4740BBB239C2426D00C046571000828D47402CA719B6357200C0EB65BC9E078F4740B2725213C07500C0FECDB3F78E9047409F631E74E07700C0E09F397017924740EB1B9B01967800C07EF4396DA09347409F631E74E07700C0F762875329954740B3725213C07500C02E561888B19647402EA719B6357200C0B029447038984740BCB239C2426D00C02EF6FF71BD9947402A61CE2BE96600C0AFF51AF43F9B4740852F84742B5F00C09E687A5EBF9C4740DB019BAA0C5600C0A4E4541A3B9E47408C5BB167904B00C053F76C92B29F4740039458CFBA3F00C0B7064B3325A147408C97728D903200C0AB5A766B92A247404AD959D4162400C04C3AADABF9A34740AA30D45A531400C065091C675AA54740A171D1594C0300C067529313B4A647402547ED1311E2FFBFFDA9BC2906A84740589EED411EBBFFBF085A4E2550A947406DDE749DCF91FFBF5BC23D8591AA4740F647AD743566FFBF345EF0CBC9AB4740DFB7AAFD6038FFBF2F5E6B7FF8AC47407A6D9F4F6408FFBF06C781291DAE4740F3F3B75B52D6FEBF0106015837AF4740C300A1E53EA2FEBFF7ECDB9C46B047409F3ABA7B3E6CFEBFF507548E4AB147405FFDF86E6634FEBFC23F21C742B24740B64E7ECACCFAFDBFD0BC97E62EB347400F56E34A88BFFDBFF4FECB900EB44740E1C63F55B082FDBFF31EB56EE1B4474049C8EDED5C44FDBF8C2F4D2EA7B547403CFF0EAFA604FDBF48B4AF825FB647404479D6BEA6C3FCBF262536240AB74740164D9BC57681FCBFA67692D0A6B747403ADCB7E3303EFCBF9F9EE74A35B847402FB539A7EFF9FBBFB40EE05BB5B8474037286601CEB4FBBF011EC2D126B94740EAB1173CE76EFBBF305C828089B947407C6EF8EE5628FBBFC8C8D341DDB94740F1D59DF438E1FABF2EEA35F521BA4740190E8A5FA999FABF53C0008057BA47402D29176FC451FABFD68F6ECD7DBA4740FEB05084A609FABFCD82A3CE94BA474062E5BF166CC1F9BF161DB37A9CBA4740C5192FA93179F9BFCD82A3CE94BA474096A168BE1331F9BFD68F6ECD7DBA4740AABCF5CD2EE9F8BF53C0008057BA4740D2F4E1389FA1F8BF2EEA35F521BA4740475C873E815AF8BFC8C8D341DDB94740D91868F1F013F8BF305C828089B947408CA2192C0ACEF7BF021EC2D126B9474091154686E888F7BFB40EE05BB5B8474088EEC749A744F7BF9F9EE74A35B84740AB7DE4676101F7BFA67692D0A6B747407C51A96E31BFF6BF262536240AB7474083CB707E317EF6BF48B4AF825FB647407602923F7B3EF6BF8C2F4D2EA7B54740DD0340D82700F6BFF31EB56EE1B44740AF749CE24FC3F5BFF4FECB900EB44740087C01630B88F5BFD1BC97E62EB347405DCD86BE714EF5BFC33F21C742B247401C90C5B19916F5BFF507548E4AB14740F8C9DE4799E0F4BFF8ECDB9C46B04740C4D6C7D185ACF4BF0106015837AF47403C5DE0DD737AF4BF06C781291DAE4740D612D52F774AF4BF305E6B7FF8AC4740BD82D2B8A21CF4BF345EF0CBC9AB474046EC0A9008F1F3BF5BC23D8591AA4740572C92EBB9C7F3BF095A4E2550A947408A839219C7A0F3BFFDA9BC2906A847406CE7DC793F7CF3BF67529313B4A647405869D777315AF3BF65091C675AA547401818CC84AA3AF3BF4C3AADABF9A34740939B9A12B71DF3BFAB5A766B92A24740A4A2CE8E6203F3BFB7064B3325A1474090131D5EB7EBF2BF54F76C92B29F4740F0C649D8BED6F2BFA4E4541A3B9E47409D6B774481C4F2BF9E687A5EBF9C47405108E3D505B5F2BFAFF51AF43F9B47402C650CA952A8F2BF2EF6FF71BD994740487C4CC16C9EF2BFB2294470389847403FE5DA065897F2BF2E561888B1964740640343451793F2BFF762875329954740CC92492AAC91F2BF7EF4396DA0934740	1	50000	LFRS
0105000020E6100000010000000102000000A100000009B77345B1C8D0BF7EF4396DA093474030FE2489B6D9D0BF6B891F32058F47406594439CBF0CD1BF6C65AAFC6A8A4740DCA89659B861D1BFBECF539FD38547407D9395367FD8D1BF42AD64EC408147404539A550E570D2BFB2CC39B5B47C4740D2E0997FAE2AD3BFD51B87C930784740B428766D9105D4BFEF179AF6B673474031C05DB33701D5BFA8CE9B06496F47401875B0FB3D1DD6BFB3C6D2BFE86A47404D2040293459D7BFEB29E5E39766474085F691839DB4D8BF4B8C1B2F586247407DC519E8F02EDABF0FADA4572B5E47406FAE5B0099C7DBBF9290DA0C135A4740C7FFDE7CF47DDDBFB65289F61056474064E9DA545651DFBF961238B4265247404AF4410583A0E0BF9C5874DC554E4740147BEFF91FA6E1BFA15820FC9F4A47409FDBFEC31AB9E2BF9071C49506474740049A42D806D9E3BF904BE4208B4347403373AF8F7205E5BF41F557092F4047405E263954E73DE6BF6F5FA9AEF33C474037CBA1CFE981E7BF41957663DA394740BC3A291CFAD0E8BF550DD96CE4364740B85209F7932AEABF2A6ED201133447409A26ABF42E8EEBBFDE1DBF4A67314740AE8180B63EFBECBFB0F2CE60E22E474040796C223371EEBFA856844D852C47408C2FA59B78EFEFBF8C2D3A0A512A4740AE297C1EBCBAF0BFCBC8B07F462847403AAE2D0A4C81F1BFE130A28566264740CE00D8AF1D4BF2BF0D085EE2B1244740EA755265E117F3BF56456D4A29234740D81CCD5646E7F3BF78023E60CD214740BB7FB8A6FAB8F4BF7C92D7B39E204740064A168EAB8CF5BF871197C29D1F4740A113267D0562F6BF4499F4F6CA1E47402B6B613CB438F7BFD93F51A8261E4740F019BA0D6310F8BFBD01CE1AB11D474077820DCEBCE8F8BF1AB12B7F6A1D47404CE5BF166CC1F9BF87FFB3F2521D47402248725F1B9AFABF1AB12B7F6A1D4740A9B0C51F7572FBBFBD01CE1AB11D47406E5F1EF1234AFCBFD93F51A8261E4740F9B659B0D220FDBF4499F4F6CA1E47409480699F2CF6FDBF871197C29D1F4740DD4AC786DDC9FEBF7C92D7B39E204740C2ADB2D6919BFFBF78023E60CD21474057AA16647B3500C056456D4A29234740E6E4D33EDD9B00C00D085EE2B1244740300EA911C60001C0E030A2856626474076D081070E6401C0CBC8B07F462847406A99D6EF8DC501C08C2D3A0A512A4740FCC6244E1F2502C0A856844D852C4740E1C41F699C8202C0B0F2CE60E22E4740A51B9559E0DD02C0DE1DBF4A673147409D90FD18C73603C02A6ED201133447409B96B58F2D8D03C0550DD96CE43647407C72D7A2F1E003C041957663DA394740B29BB141F23104C06F5FA9AEF33C47407D08D4720F8004C041F557092F404740C83EAF602ACB04C0904BE4208B434740622EC065251305C09071C4950647474084064418E45705C0A15820FC9F4A474037686F554B9905C09B5874DC554E47401D88244C41D705C0961238B42652474051052487AD1106C0B65289F6105647407B6FB4F6784806C09290DA0C135A47409BACBCF98D7B06C00EADA4572B5E47407AA64D66D8AA06C04B8C1B2F5862474042E1979145D606C0EB29E5E397664740A9D64957C4FD06C0B2C6D2BFE86A4740462D5420452107C0A6CE9B06496F4740352011E9B94007C0EE179AF6B673474033A9CC46165C07C0D41B87C930784740233EAB6C4F7307C0B1CC39B5B47C4740DF32ED2F5C8607C042AD64EC4081474032108D0B359507C0BECF539FD3854740C3723723D49F07C06B65AAFC6A8A47408A459B4535A607C06B891F32058F4740706E11EE55A807C07DF4396DA09347408C459B4535A607C0D2490ADC3A984740C6723723D49F07C02EB0E3ADD29C474038108D0B359507C0786D121466A14740E632ED2F5C8607C02B3E9042F3A547402D3EAB6C4F7307C02125B67078AA47403CA9CC46165C07C0C773EBD9F3AE4740412011E9B94007C0EDCD51BE63B34740532D5420452107C00BF06D63C6B74740B8D64957C4FD06C01402CD141ABC474052E1979145D606C09544A6245DC047408CA64D66D8AA06C01BE978EC8DC44740ADACBCF98D7B06C05EEAA5CDAAC84740916FB4F6784806C016BC0532B2CC474068052487AD1106C06CAD798CA2D047403688244C41D705C073DC78597AD4474051686F554B9905C0F89B981F38D84740A0064418E45705C00F301070DADB47407E2EC065251305C0A8C837E75FDF4740E73EAF602ACB04C00EA4022DC7E247409C08D4720F8004C0FF4574F50EE64740D29BB141F23104C05FB2100136E947409D72D7A2F1E003C0E49C471D3BEC4740BC96B58F2D8D03C01881DA241DEF4740BE90FD18C73603C045983D00DBF14740C61B9559E0DD02C087A4F3A573F4474002C51F699C8202C0D289E41AE6F647401DC7244E1F2502C071AFAE7231F947408A99D6EF8DC501C09425F3CF54FB474095D081070E6401C0C58B9C644FFD4740500EA911C60001C036B6207220FF474005E5D33EDD9B00C06310BD49C700484076AA16647B3500C096BCAD4C43024840FFADB2D6919BFFBF17705FEC930348401A4BC786DDC9FEBF700C9CAAB8044840CF80699F2CF6FDBF65F6B119B105484032B759B0D220FDBF7B2B96DC7C064840A95F1EF1234AFCBFFF1601A71B074840E1B0C51F7572FBBF7727863D8D0748405A48725F1B9AFABF6925A675D107484083E5BF166CC1F9BF2F4CDC35E8074840AC820DCEBCE8F8BF6925A675D1074840231ABA0D6310F8BF7727863D8D0748405D6B613CB438F7BFFF1601A71B074840D113267D0562F6BF7C2B96DC7C064840344A168EAB8CF5BF65F6B119B1054840E87FB8A6FAB8F4BF710C9CAAB8044840021DCD5646E7F3BF18705FEC9303484013765265E117F3BF97BCAD4C43024840F500D8AF1D4BF2BF6310BD49C70048405FAE2D0A4C81F1BF37B6207220FF4740D1297C1EBCBAF0BFC68B9C644FFD4740CF2FA59B78EFEFBF9525F3CF54FB474080796C223371EEBF72AFAE7231F94740E98180B63EFBECBFD389E41AE6F64740D226ABF42E8EEBBF89A4F3A573F44740EC5209F7932AEABF47983D00DBF14740ED3A291CFAD0E8BF1981DA241DEF474066CBA1CFE981E7BFE69C471D3BEC474088263954E73DE6BF61B2100136E947405973AF8F7205E5BFFF4574F50EE64740289A42D806D9E3BF0FA4022DC7E24740BDDBFEC31AB9E2BFABC837E75FDF4740307BEFF91FA6E1BF11301070DADB474064F4410583A0E0BFF99B981F38D847408FE9DA545651DFBF75DC78597AD44740F2FFDE7CF47DDDBF6DAD798CA2D0474090AE5B0099C7DBBF19BC0532B2CC47409AC519E8F02EDABF60EAA5CDAAC847409CF691839DB4D8BF1BE978EC8DC44740602040293459D7BF9744A6245DC047402575B0FB3D1DD6BF1502CD141ABC47403BC05DB33701D5BF0CF06D63C6B74740BE28766D9105D4BFEECD51BE63B34740DBE0997FAE2AD3BFC973EBD9F3AE47404A39A550E570D2BF2325B67078AA47407D9395367FD8D1BF2C3E9042F3A54740DCA89659B861D1BF796D121466A147406594439CBF0CD1BF2EB0E3ADD29C474030FE2489B6D9D0BFD4490ADC3A98474009B77345B1C8D0BF7EF4396DA0934740	3	150000	LFRS
\.


--
-- TOC entry 4762 (class 0 OID 47464)
-- Dependencies: 305
-- Data for Name: runways; Type: TABLE DATA; Schema: meta; Owner: dump1090
--

COPY meta.runways (id, geom, airport_icao, name, direction, length) FROM stdin;
1	0103000020E610000001000000080000006338481023EBF9BF660D92C9229247409CCC010EC7EEF9BF008918882C92474023E6615885EFF9BF740FD4D3E4914740542C8128B1E4F9BFC42C7C0E129247404AAFAD6580E8F9BF0EAEF79D1B9247408F8714A9DC9EF9BFA02617711E95474021BE4A2CCDA1F9BFED2773E2259547406338481023EBF9BF660D92C922924740	LFRS	21	210	\N
2	0103000020E61000000100000008000000EEF324E02DEBF9BF640D92C9229247404AAFAD6580E8F9BF0EAEF79D1B9247408F8714A9DC9EF9BFA02617711E954740EAECC218099BF9BF06EDB0E214954740F9C9A8975F9BF9BF0919F5A152954740B222BA8368A5F9BF8AC5412A2F95474021BE4A2CCDA1F9BFED2773E225954740EEF324E02DEBF9BF640D92C922924740	LFRS	03	30	\N
\.


--
-- TOC entry 4781 (class 0 OID 0)
-- Dependencies: 302
-- Name: airports_id_seq; Type: SEQUENCE SET; Schema: meta; Owner: dump1090
--

SELECT pg_catalog.setval('meta.airports_id_seq', 1, false);


--
-- TOC entry 4782 (class 0 OID 0)
-- Dependencies: 307
-- Name: runways_id_0_seq; Type: SEQUENCE SET; Schema: meta; Owner: dump1090
--

SELECT pg_catalog.setval('meta.runways_id_0_seq', 2, true);


--
-- TOC entry 4619 (class 2606 OID 47480)
-- Name: airports airports_pk; Type: CONSTRAINT; Schema: meta; Owner: dump1090
--

ALTER TABLE ONLY meta.airports
    ADD CONSTRAINT airports_pk PRIMARY KEY (icao);


--
-- TOC entry 4621 (class 2606 OID 47513)
-- Name: range_rings range_rings_pk; Type: CONSTRAINT; Schema: meta; Owner: dump1090
--

ALTER TABLE ONLY meta.range_rings
    ADD CONSTRAINT range_rings_pk PRIMARY KEY (id);


--
-- TOC entry 4623 (class 2606 OID 47486)
-- Name: runways runways_pkey; Type: CONSTRAINT; Schema: meta; Owner: dump1090
--

ALTER TABLE ONLY meta.runways
    ADD CONSTRAINT runways_pkey PRIMARY KEY (id);


--
-- TOC entry 4625 (class 2606 OID 47493)
-- Name: runways airports_icao_fk; Type: FK CONSTRAINT; Schema: meta; Owner: dump1090
--

ALTER TABLE ONLY meta.runways
    ADD CONSTRAINT airports_icao_fk FOREIGN KEY (airport_icao) REFERENCES meta.airports(icao) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4624 (class 2606 OID 47514)
-- Name: range_rings airports_icao_fk; Type: FK CONSTRAINT; Schema: meta; Owner: dump1090
--

ALTER TABLE ONLY meta.range_rings
    ADD CONSTRAINT airports_icao_fk FOREIGN KEY (icao) REFERENCES meta.airports(icao) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4774 (class 0 OID 0)
-- Dependencies: 300
-- Name: TABLE airports; Type: ACL; Schema: meta; Owner: dump1090
--

GRANT SELECT ON TABLE meta.airports TO graphql;


--
-- TOC entry 4775 (class 0 OID 0)
-- Dependencies: 301
-- Name: TABLE airports_geojson; Type: ACL; Schema: meta; Owner: dump1090
--

GRANT SELECT,REFERENCES ON TABLE meta.airports_geojson TO graphql;


--
-- TOC entry 4776 (class 0 OID 0)
-- Dependencies: 303
-- Name: TABLE range_rings; Type: ACL; Schema: meta; Owner: dump1090
--

GRANT SELECT,REFERENCES ON TABLE meta.range_rings TO graphql;


--
-- TOC entry 4777 (class 0 OID 0)
-- Dependencies: 304
-- Name: TABLE range_rings_geojson; Type: ACL; Schema: meta; Owner: dump1090
--

GRANT SELECT,REFERENCES ON TABLE meta.range_rings_geojson TO graphql;


--
-- TOC entry 4778 (class 0 OID 0)
-- Dependencies: 305
-- Name: TABLE runways; Type: ACL; Schema: meta; Owner: dump1090
--

GRANT SELECT,REFERENCES ON TABLE meta.runways TO graphql;


--
-- TOC entry 4779 (class 0 OID 0)
-- Dependencies: 306
-- Name: TABLE runways_geojson; Type: ACL; Schema: meta; Owner: dump1090
--

GRANT SELECT,REFERENCES ON TABLE meta.runways_geojson TO graphql;


--
-- TOC entry 3521 (class 826 OID 47498)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: meta; Owner: dump1090
--

ALTER DEFAULT PRIVILEGES FOR ROLE dump1090 IN SCHEMA meta REVOKE ALL ON TABLES  FROM dump1090;
ALTER DEFAULT PRIVILEGES FOR ROLE dump1090 IN SCHEMA meta GRANT SELECT,REFERENCES ON TABLES  TO graphql;


-- Completed on 2021-07-25 16:55:19 UTC

--
-- PostgreSQL database dump complete
--
