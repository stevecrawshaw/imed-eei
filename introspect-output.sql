duckdb data/imed_eei.duckdb

INSTALL SPATIAL;
LOAD SPATIAL;
INSTALL HTTPFS;
LOAD HTTPFS;

ATTACH '' AS weca_postgres (TYPE POSTGRES, SECRET weca_postgres);

CREATE OR REPLACE TABLE lep_boundary_tbl AS
SELECT name, id, ST_Transform(shape, 'EPSG:27700', 'EPSG:4326', always_xy => true) AS geometry
FROM weca_postgres.os.bdline_ua_lep_diss;

COPY lep_boundary_tbl TO 'data/lep_boundary_4326.fgb' (FORMAT GDAL, DRIVER 'FlatGeoBuf');
-- DESCRIBE lep_boundary_tbl;

-- FROM lep_boundary_tbl LIMIT 5;

DETACH weca_postgres;

CREATE OR REPLACE TABLE imed_eei_tbl AS
SELECT *, ST_Point(lon, lat) AS geometry
FROM read_parquet('output/eei_imed_points.parquet');

.read 'scripts/add_metadata_comments.sql'

DESCRIBE imed_eei_tbl;

SELECT comment FROM duckdb_columns WHERE table_name = 'imed_eei_tbl';

FROM imed_eei_tbl LIMIT 5;

SELECT COUNT() FROM imed_eei_tbl;

-- LSOA boundaries

CREATE OR REPLACE TABLE lsoa_boundaries_lep AS
SELECT * FROM ST_Read('https://opendata.westofengland-ca.gov.uk/api/explore/v2.1/catalog/datasets/lep_lsoa_geog/exports/fgb/?lang=en&timezone=Europe%2FLondon');

DESCRIBE lsoa_boundaries_lep;

CREATE OR REPLACE VIEW imed_eei_in_lep AS
SELECT imed_eei_tbl.* EXCLUDE (geometry),
'{' || imed_eei_tbl.lat || ',' || imed_eei_tbl.lon || '}' AS geo_point_2d,
lsoa_boundaries_lep.ladcd, lsoa_boundaries_lep.ladnm, lsoa_boundaries_lep.lsoa21cd,
lsoa_boundaries_lep.wd24cd, lsoa_boundaries_lep.wd24nm, lsoa_boundaries_lep.msoacd
FROM imed_eei_tbl
JOIN lep_boundary_tbl
ON ST_Contains(lep_boundary_tbl.geometry, imed_eei_tbl.geometry)
JOIN lsoa_boundaries_lep
ON ST_Contains(lsoa_boundaries_lep.geom, imed_eei_tbl.geometry);


-- export data to csv for open data portal - NOT PUBLISHED YET
COPY imed_eei_in_lep TO 'output/imed_eei_in_lep.csv' (FORMAT CSV, HEADER TRUE);

-- Combined authority boundaries

CREATE OR REPLACE TABLE ca_boundary_tbl AS
SELECT * FROM ST_Read('https://opendata.westofengland-ca.gov.uk/api/explore/v2.1/catalog/datasets/cauths_weca_as_lep/exports/fgb/?lang=en&timezone=Europe%2FLondon');

SUMMARIZE ca_boundary_tbl;

FROM lsoa_boundaries_lep LIMIT 5;
