# imed-eei

Convert England's Environmental Equity Index (EEI) and Index of Multiple Environmental Deprivation (IMED) raster datasets into a single tabular points dataset, ready for analysis in DuckDB, R, or Python.

[![Licence](https://img.shields.io/badge/license-MIT-blue.svg)](LICENCE)

## About

The EEI/IMED data ships as ~34 separate GeoTIFF rasters (one per domain, sub-domain, and indicator), each zipped individually, all on a shared 100m British National Grid (EPSG:27700). That's an awkward shape for anything beyond viewing in a desktop GIS.

This repo unzips every raster, extracts every populated grid cell, and joins them all into one wide table: one row per 100m cell, one column per indicator, with both British National Grid (easting/northing) and WGS84 (lon/lat) coordinates attached. The result is a single Parquet file rather than 34 rasters — queryable directly with DuckDB, and loadable in R (`arrow`/`sf`) or Python (`pandas`/`geopandas`) without any GIS tooling.

## Data

Source rasters live as zip files in `data/` (not tracked in git — see [Data source](#data-source) below). Each zip contains a single-band GeoTIFF plus ArcGIS sidecar files (`.tif.aux.xml`, `.tif.ovr`, `.lyrx`, sometimes a `.vat.dbf` raster attribute table) and a metadata PDF.

Two raster families are present, at different spatial coverage:

| Family | Coverage | Example |
| --- | --- | --- |
| `*_EEI_*` | Built-up areas only (~2.2M cells) | `Domain_EEI_Decile`, `Indicator_EEI_Poll_NO2_2021_2023` |
| `*_IMED_*` / plain `Indicator_*` | Full extent (~13.3M cells) | `Domain_IMED_Score`, `Indicator_Poll_NO2_2021_2023` |

EEI coverage is a strict subset of IMED coverage. Rows outside a given raster's extent hold `NULL` for that column rather than being dropped.

### Data source

Source zips aren't committed to this repo. Place them in `data/` before running the pipeline — the script picks up every `*.zip` file found there. Confirm licensing/redistribution terms for the underlying EEI/IMED data with its publisher before treating output derived from it as open data in its own right.

## Requirements

- R (tested on 4.5) with these packages: `terra`, `data.table`, `arrow`, `sf`, `duckdb`
- [DuckDB CLI](https://duckdb.org/docs/installation/) with the `spatial` extension, if you want to query or export geometry directly (installed on first use via `INSTALL spatial;`)

```r
install.packages(c("terra", "data.table", "arrow", "sf", "duckdb"))
```

## Usage

```bash
# defaults: reads every zip in data/, writes output/eei_imed_points.parquet
Rscript scripts/rasters_to_points.R

# or point it at different directories
Rscript scripts/rasters_to_points.R path/to/data path/to/output
```

The script:

1. Unzips each raster into `data/extracted/<name>/` (skipped on subsequent runs — delete the folder to force re-extraction)
2. Builds a common template grid covering the union extent of all rasters
3. Extracts every non-`NA` cell from each raster, keyed by a shared `cell_id`
4. Full-outer-joins all rasters into one wide table
5. Attaches `easting`/`northing` (EPSG:27700) and `lon`/`lat` (EPSG:4326)
6. Writes `output/eei_imed_points.parquet`

### Querying the output

```sql
-- DuckDB
SELECT lon, lat, Domain_EEI_Decile, Domain_IMED_Score
FROM 'output/eei_imed_points.parquet'
WHERE Domain_EEI_Decile = 1;
```

### Exporting a GIS-friendly subset

The full output is ~13.3M rows — too many point features for GeoPackage or FlatGeobuf to handle gracefully (both balloon to multiple GB at this cardinality). Filter to a region or a handful of columns first, then export:

```sql
INSTALL spatial; LOAD spatial;
COPY (
    SELECT * EXCLUDE (easting, northing), ST_Point(lon, lat) AS geom
    FROM 'output/eei_imed_points.parquet'
    WHERE Domain_EEI_Decile IS NOT NULL  -- e.g. restrict to EEI's built-up-area extent
) TO 'output/eei_subset.gpkg' WITH (FORMAT GDAL, DRIVER 'GPKG');
```

## Gotchas

- **Raster filenames inside a zip don't always match the zip name** (e.g. `Indicator_BE_LackofTrees.zip` contains `Indicator_Nature_LackofTrees.tif`). Output columns are named after the *zip*, not the internal `.tif`, for consistency.
- **Grid extents differ slightly between rasters** even though origin, resolution, and CRS are identical — the union template grid handles this without resampling (values are never interpolated, only reindexed).
- **`data/extracted/` is a cache**, not throwaway scratch — expect ~4-5GB once every zip has been unzipped once. Safe to delete; it regenerates automatically.

## Licence

MIT — see [LICENCE](LICENCE).
