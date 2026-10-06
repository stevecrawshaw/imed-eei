-- =============================================================================
-- add_metadata_comments.sql
--
-- Adds COMMENT ON TABLE / COMMENT ON COLUMN metadata to imed_eei_tbl so that
-- an AI coding agent can interpret column meaning, scale and polarity without
-- external documentation.
--
-- Source metadata: eei-metadata.txt, imed-metadata.txt (scraped from an
-- online mapping service's layer legends).
--
-- Run with:
--   duckdb data/imed_eei.duckdb -f scripts/add_metadata_comments.sql
--
-- Polarity convention used throughout (see "MISSING / UNCERTAIN METADATA"
-- section at the end for exceptions and caveats):
--   * All *_Score / SubDomain_* / Indicator_* columns are scored 0-10, where
--     HIGHER = WORSE (greater pressure, burden, deprivation or risk) and
--     LOWER = BETTER, UNLESS the column description says otherwise
--     (e.g. "Access to Greenspace" indicators, see caveat below).
--   * All *_Decile / *_Decile_* columns are INVERTED relative to the score:
--     Decile 1 = HIGHEST pressure (worst), Decile 10 = LOWEST pressure
--     (best). This is the opposite direction to the raw score columns and
--     is the single most important gotcha for correct interpretation.
-- =============================================================================

COMMENT ON TABLE imed_eei_tbl IS
'Point grid (100m British National Grid cells) covering built-up areas,
combining two related composite environmental-inequality indices:
  - IMED (Inequalities in Multiple Environmental Deprivation): scored across
    the full study area.
  - EEI (Environmental Equality Index): scored for built-up land ONLY (a
    subset of IMED restricted to built-up areas), suffix "_EEI_" or "EEI" in
    column names, or "Domain_EEI_*"/"SubDomain_EEI_*"/"Indicator_EEI_*".
Each index is a hierarchy: Domain (overall) -> Sub-Domain (Pollution,
Nature, Health & Social, Climate, Built Environment) -> Indicator (individual
measured variable). All composite scores are 0-10, HIGHER = WORSE (greater
pressure/deprivation), except decile columns which are INVERTED: Decile 1 =
worst, Decile 10 = best. One row per 100m grid cell (see cell_id, easting,
northing). Source: scraped mapping-service legends in eei-metadata.txt and
imed-metadata.txt; column-name mappings to those legends were inferred where
names differ (see COMMENT on affected columns) and should be verified
against the original online mapping service.';

-- -----------------------------------------------------------------------
-- Identifiers / spatial columns (no legend metadata scraped for these)
-- -----------------------------------------------------------------------

COMMENT ON COLUMN imed_eei_tbl.cell_id IS
'Grid cell identifier (double-typed but integer-valued). Not documented in
scraped legends. Appears to be a sequential/row-major index over the
national 100m grid rather than a directly-derivable coordinate encoding
(row order does not match easting/northing order). Treat as an opaque
primary key only; do not assume arithmetic meaning. MISSING METADATA -
source definition from the original data provider''s technical
documentation, not the map legend.';

COMMENT ON COLUMN imed_eei_tbl.easting IS
'British National Grid (OSGB36, EPSG:27700) easting in metres, cell centre.
Grid resolution is 100m (confirmed from data: min spacing between distinct
values = 100). Not in scraped legends; CRS inferred from coordinate range
(fits Great Britain) - verify against source before reprojecting.';

COMMENT ON COLUMN imed_eei_tbl.northing IS
'British National Grid (OSGB36, EPSG:27700) northing in metres, cell centre.
100m grid resolution. See easting comment for CRS caveat.';

COMMENT ON COLUMN imed_eei_tbl.lon IS
'Longitude, WGS84 (EPSG:4326), decimal degrees - derived reprojection of
easting/northing. CRS inferred, not documented in source legends.';

COMMENT ON COLUMN imed_eei_tbl.lat IS
'Latitude, WGS84 (EPSG:4326), decimal degrees - derived reprojection of
easting/northing. CRS inferred, not documented in source legends.';

COMMENT ON COLUMN imed_eei_tbl.geometry IS
'DuckDB spatial GEOMETRY (POINT), one point per 100m grid cell centre.
Coordinates match lon/lat (WGS84/EPSG:4326) based on sample inspection;
no explicit SRID metadata was found in the source files - confirm via
ST_SRID(geometry) / the original export pipeline if reprojection is needed.';

-- -----------------------------------------------------------------------
-- IMED - Domain (overall, whole study area)
-- -----------------------------------------------------------------------

COMMENT ON COLUMN imed_eei_tbl.Domain_IMED_Score IS
'IMED overall composite score, 0-10. 0-1 = Lowest Environmental Pressure,
10 = Highest Environmental Pressure. Polarity: HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Domain_IMED_Decile IS
'IMED overall score, deciled, 1-10. Decile 1 = Highest Pressure,
Decile 10 = Lowest Pressure. Polarity: INVERTED vs Domain_IMED_Score -
LOWER decile number = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Domain_IMED_Score_Decile_PopWeighted_100m IS
'IMED overall score deciled and population-weighted at 100m resolution.
Decile 1 = Highest Environmental Pressure by Population, Decile 10 = Lowest.
Polarity: INVERTED (as per other deciles) - LOWER decile = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Domain_IMED_Score_Decile_PopWeighted_LSOA IS
'IMED overall score deciled and population-weighted, aggregated at LSOA
(Lower Layer Super Output Area) level rather than per-cell. Decile 1 =
Highest Environmental Pressure by Population, Decile 10 = Lowest. Polarity:
INVERTED - LOWER decile = WORSE. NOTE: this is an area-level statistic
attached to point cells within that LSOA, not a per-cell calculation.';

-- -----------------------------------------------------------------------
-- IMED - Sub-Domains
-- -----------------------------------------------------------------------

COMMENT ON COLUMN imed_eei_tbl.SubDomain_IMED_Pollution IS
'IMED Pollution Burden sub-domain score, 0-10. 0-1 = Less Pollution,
9-10 = Greater Pollution. Polarity: HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.SubDomain_IMED_Nature IS
'IMED Nature Deficit Burden sub-domain score, 0-10. 0-1 = Less Nature
Deficit Burden, 9-10 = Greater Nature Deficit Burden. Polarity: HIGHER =
WORSE (i.e. higher = greater deficit of nature/green infrastructure).';

COMMENT ON COLUMN imed_eei_tbl.SubDomain_IMED_Climate IS
'IMED Climate Risk Burden sub-domain score, 0-10. 0-1 = Less Climate
Burden, 9-10 = Greater Climate Burden. Polarity: HIGHER = WORSE.';

-- -----------------------------------------------------------------------
-- IMED - Indicators
-- -----------------------------------------------------------------------

COMMENT ON COLUMN imed_eei_tbl.Indicator_Nature_AccessToGreenspace IS
'IMED indicator: lack of access to greenspace, 0-10. 0-1 = Greater Access
to Greenspace, 10 = Less Access to Greenspace. Polarity: HIGHER = WORSE
(less access). NOTE: the equivalent EEI-prefixed indicator
(Indicator_EEI_Nature_AccessToGreenspace) has an apparently inconsistent
scraped legend - see MISSING/UNCERTAIN METADATA note below.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_Nature_QualityHabitatDeficit IS
'IMED indicator: quality habitat deficit, 0-10. 0 = Presence of Quality
Habitat, 10 = Lack of Quality Habitat. Polarity: HIGHER = WORSE (greater
deficit of quality habitat). Stored as INTEGER in this table (only
value-quantised indicator among the Indicator_* columns).';

COMMENT ON COLUMN imed_eei_tbl.Indicator_Climate_ProjectedHeat IS
'IMED indicator: projected increase in summer days >28C, 2030s vs 1980s,
0-10. 0-1 = Less Chance of Number of Days >28C, 10 = Greater Chance.
Polarity: HIGHER = WORSE (more hot days). Reference period: 2030s vs 1980s
baseline (as stated in legend).';

COMMENT ON COLUMN imed_eei_tbl.Indicator_Climate_FRSW IS
'IMED indicator: flood risk from surface water, 0-10, quantised to
{0, 2.5, 5, 7.5, 10}. 0 = Low Flood Risk, 10 = High Flood Risk. Polarity:
HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_Climate_FRRS IS
'IMED indicator: flood risk from rivers & seas, 0-10, quantised to
{0, 5, 7.5, 10} in the scraped legend (2.5 not observed for this
indicator - see MISSING/UNCERTAIN METADATA). 0 = Low Flood Risk, 10 = High
Flood Risk. Polarity: HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_Pollution_Noise IS
'IMED indicator: noise pollution, 0-10. 0-1 = Least Pollution, 9-10 =
Greatest Pollution. Polarity: HIGHER = WORSE. NOTE: column name differs
from the scraped legend key "Indicator_Poll_Noise" in imed-metadata.txt -
mapped by matching sub-domain/description and value range; verify against
source.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_Poll_NO2_2021_2023 IS
'IMED indicator: nitrogen dioxide (NO2) pollution, 2021-2023, 0-10.
0-1 = Least Pollution, 9-10 = Greatest Pollution. Polarity: HIGHER = WORSE.
Reference period: 2021-2023.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_Poll_PM25_2021_2023 IS
'IMED indicator: particulate matter PM2.5 pollution, 2021-2023, 0-10.
0-1 = Least Pollution, 9-10 = Greatest Pollution. Polarity: HIGHER = WORSE.
Reference period: 2021-2023.';

-- -----------------------------------------------------------------------
-- EEI - Domain (overall, built-up area only)
-- -----------------------------------------------------------------------

COMMENT ON COLUMN imed_eei_tbl.Domain_EEI_Score IS
'EEI overall composite score, built-up area ONLY, 0-10. 0-1 = Lowest
Pressure, 9-10 = Highest Pressure. Polarity: HIGHER = WORSE. EEI is scored
only where land is classified built-up; NULL/absence elsewhere is expected
- see MISSING/UNCERTAIN METADATA note on built-up-area masking below.';

COMMENT ON COLUMN imed_eei_tbl.Domain_EEI_Decile IS
'EEI overall score, deciled, built-up area ONLY, 1-10. Decile 1 = Highest
Pressure, Decile 10 = Lowest Pressure. Polarity: INVERTED vs
Domain_EEI_Score - LOWER decile = WORSE.';

-- -----------------------------------------------------------------------
-- EEI - Sub-Domains
-- -----------------------------------------------------------------------

COMMENT ON COLUMN imed_eei_tbl.SubDomain_EEI_Pollution IS
'EEI Pollution Burden sub-domain score, built-up area ONLY, 0-10.
0-1 = Less Pollution Burden, 9-10 = Greater Pollution Burden. Polarity:
HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.SubDomain_EEI_Nature IS
'EEI Nature Deficit Burden sub-domain score, built-up area ONLY, 0-10.
0-1 = Less Nature Burden, 9-10 = Greater Nature Deficit Burden. Polarity:
HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.SubDomain_EEI_HS IS
'EEI Health and Social (H&S) Vulnerability Burden sub-domain score,
built-up area ONLY, 0-10. 0-1 = Less H&S Burden, 9-10 = Greater H&S
Burden. Polarity: HIGHER = WORSE. This sub-domain has no IMED-prefixed
equivalent in the scraped metadata (Health & Social burden is only scored
within EEI, not within the wider IMED index).';

COMMENT ON COLUMN imed_eei_tbl.SubDomain_EEI_Climate IS
'EEI Climate Risk Burden sub-domain score, built-up area ONLY, 0-10.
0-1 = Less Climate Risk Burden, 9-10 = Greater Climate Risk Burden.
Polarity: HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.SubDomain_EEI_BE IS
'EEI Built Environment sub-domain score, built-up area ONLY, 0-10.
0-1 = Less Built Environmental Burden, 9-10 = Greater Built Environmental
Burden. Polarity: HIGHER = WORSE. Scraped legend key was "Sub-Domain_EEI_BE"
(with hyphen); this table uses "SubDomain_EEI_BE". This sub-domain (and
its two indicators, Indicator_BE_LackofTrees / Indicator_BE_UHI) has no
IMED-prefixed equivalent - Built Environment is scored only within EEI.';

-- -----------------------------------------------------------------------
-- EEI - Indicators
-- -----------------------------------------------------------------------

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Poll_PM25_2021_2023 IS
'EEI indicator: particulate matter PM2.5 pollution, 2021-2023, built-up
area ONLY, 1-10. 1 = Least Pollution, 10 = Greatest Pollution. Polarity:
HIGHER = WORSE. Reference period: 2021-2023. NOTE: scale starts at 1, not
0, per the scraped legend (unlike most other indicators which start at 0).';

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Poll_Noise IS
'EEI indicator: noise pollution, built-up area ONLY, 1-10. 1 = Least
Pollution, 10 = Greatest Pollution. Polarity: HIGHER = WORSE. Scale starts
at 1, not 0.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Poll_NO2_2021_2023 IS
'EEI indicator: nitrogen dioxide (NO2) pollution, 2021-2023, built-up area
ONLY, 1-10. 1 = Least Pollution, 10 = Greatest Pollution. Polarity: HIGHER
= WORSE. Reference period: 2021-2023. Scale starts at 1, not 0.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Nature_QualityHabitatDeficit IS
'EEI indicator: quality habitat deficit, built-up area ONLY, 0-10.
0 = Presence of Quality Habitat, 10 = Lack of Quality Habitat. Polarity:
HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Nature_AccessToGreenspace IS
'EEI indicator: access to greenspace, built-up area ONLY, 1-10. Polarity
is  HIGHER = WORSE';

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Climate_ProjectedHeat IS
'EEI indicator: projected increase in summer days >28C (2030s vs 1980s),
built-up area ONLY, 1-10. 1 = Less Chance of Number of Days >28C, 10 =
Greater Chance. Polarity: HIGHER = WORSE. Scale starts at 1, not 0.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Climate_FRSW IS
'EEI indicator: flood risk from surface water, built-up area ONLY, 0-10,
quantised to {0, 2.5, 5, 7.5, 10}. 0 = Low Flood Risk, 10 = High Flood
Risk. Polarity: HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_EEI_Climate_FRRS IS
'EEI indicator: flood risk from rivers & seas, built-up area ONLY, 0-10,
quantised to {0, 2.5, 5, 7.5, 10}. 0 = Low Flood Risk, 10 = High Flood
Risk. Polarity: HIGHER = WORSE.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_HS_IMD IS
'EEI indicator: Indices of Multiple Deprivation (IMD), built-up area ONLY,
0-10. 0-1 = Low Deprivation, 9-10 = High Deprivation. Polarity: HIGHER =
WORSE. IMD is a standard UK Government deprivation index rescaled 0-10
here; original IMD decile/rank definitions are external to this dataset.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_HS_Years_Life_Lost_2017_2019 IS
'EEI indicator: Years of Life Lost, 2017-2019, built-up area ONLY, 0-10.
0-1 = Lower Chance of Premature Death, 9-10 = Greater Chance of Premature
Death. Polarity: HIGHER = WORSE. Reference period: 2017-2019.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_BE_LackofTrees IS
'EEI indicator (Built Environment sub-domain): lack of tree cover,
built-up area ONLY, 0-10. 0-1 = Greater Tree Cover, 9-10 = Lack of Tree
Cover. Polarity: HIGHER = WORSE (less tree cover). NOTE: column name
differs from the scraped legend key "Indicator_Nature_LackofTrees" in
eei-metadata.txt (legend groups it under "Built Environment" description
but an older "Nature" naming convention) - mapped by matching
description/value range; verify against source.';

COMMENT ON COLUMN imed_eei_tbl.Indicator_BE_UHI IS
'EEI indicator (Built Environment sub-domain): Urban Heat Island (UHI)
effect, built-up area ONLY, 0-10. 0-1 = Neutral/No Increase in UHI
Temperatures, 9-10 = Increased UHI Temperatures. Polarity: HIGHER = WORSE.
NOTE: column name differs from the scraped legend key
"Indicator_Climate_UHI" in eei-metadata.txt - mapped by matching
description/value range; verify against source.';

-- =============================================================================
-- MISSING / UNCERTAIN METADATA - summary and how to source it
-- =============================================================================
-- 1. cell_id: no definition in either legend file. Likely an internal grid
--    index from the source GIS pipeline (not derivable from easting/
--    northing order). SOURCE: ask the data provider / check any
--    accompanying technical report or metadata.xml/.json that may have
--    been provided alongside the original dataset export (not present in
--    this repo). Do not rely on the online map legend for this - legends
--    only describe styled/visible layers, not internal IDs.
--
-- 2. CRS / SRID for geometry, easting/northing, lon/lat: inferred from
--    coordinate ranges (British National Grid / WGS84) rather than stated
--    explicitly anywhere in the scraped text. SOURCE: check the export
--    script/notebook that produced output/eei_imed_points.parquet, or run
--    ST_SRID(geometry) if the CRS was embedded at creation time.
--
-- 3. Name mismatches between table columns and scraped legend keys
--    (data present, mapping inferred by description/value-range, NOT
--    verified against the live source):
--       Indicator_BE_LackofTrees      <- legend "Indicator_Nature_LackofTrees"
--       Indicator_BE_UHI              <- legend "Indicator_Climate_UHI"
--       Indicator_Pollution_Noise     <- legend "Indicator_Poll_Noise" (IMED)
--    SOURCE: re-scrape or screenshot the live legend/layer panel for each
--    of these three layers on the mapping service to confirm the mapping
--    and exact label text.
--
-- 4. Indicator_Climate_FRRS (IMED) legend is missing the "2.5" band that
--    appears for every other quantised flood-risk indicator (FRSW under
--    both IMED and EEI, and FRRS under EEI). Likely a transcription gap
--    rather than a real difference. SOURCE: re-check the "Climate-Flood
--    Risk from Rivers & Seas" IMED layer legend for a missed "2.5" entry.
--
-- 5. No stated reference/vintage period for indicators other than the four
--    that include years in their name (PM2.5, NO2: 2021-2023; Years Life
--    Lost: 2017-2019; Projected Heat: 2030s vs 1980s). Deprivation (IMD),
--    noise, greenspace access, habitat quality, flood risk, trees and UHI
--    indicators have no stated date. SOURCE: check "last updated" /
--    "data currency" notes in the mapping services layer info panel or
--    accompanying technical documentation, not the legend itself.
--
-- 6. No units/methodology documentation for how each 0-10 (or 1-10) score
--    is derived from underlying raw measurements (e.g. what raw NO2
--    concentration maps to score 10). These are index scores, not raw
--    physical units. SOURCE: the composite-index technical methodology
--    report from whichever body publishes IMED/EEI (not captured in the
--    scraped legends, which only describe display bins).
-- =============================================================================
