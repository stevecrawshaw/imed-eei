#!/usr/bin/env Rscript
# Convert every zipped IMED/EEI raster in data/ into a single wide points
# dataset: one row per 100m grid cell that has data in at least one raster,
# one column per raster (named after its zip stem), plus lon/lat (EPSG:4326)
# and easting/northing (EPSG:27700).
#
# Usage: Rscript scripts/rasters_to_points.R [data_dir] [output_dir]

library(terra)
library(data.table)

args <- commandArgs(trailingOnly = TRUE)
data_dir <- if (length(args) >= 1) args[1] else "data"
output_dir <- if (length(args) >= 2) args[2] else "output"
extract_dir <- file.path(data_dir, "extracted")
dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

zips <- list.files(data_dir, pattern = "\\.zip$", full.names = TRUE)
stopifnot(length(zips) > 0)

# --- 1. unzip everything (skip if already extracted) ------------------------
tif_for_zip <- function(zip_path) {
  stem <- tools::file_path_sans_ext(basename(zip_path))
  dest <- file.path(extract_dir, stem)
  if (!dir.exists(dest)) {
    unzip(zip_path, exdir = dest)
  }
  # the .tif filename inside the zip does not always match the zip's own
  # name (e.g. Indicator_BE_LackofTrees.zip contains Indicator_Nature_LackofTrees.tif),
  # so just take the one .tif file found under the extraction dir; sidecar
  # files (.tif.aux.xml, .tif.ovr, .tif.xml, .tif.vat.dbf) don't match "\\.tif$"
  tif <- list.files(dest, pattern = "\\.tif$", full.names = TRUE, recursive = TRUE)
  if (length(tif) != 1) {
    stop("Expected exactly one .tif under ", dest,
         " but found ", length(tif), ": ", paste(tif, collapse = ", "))
  }
  tif
}

tif_paths <- vapply(zips, tif_for_zip, character(1))
names(tif_paths) <- tools::file_path_sans_ext(basename(zips))

cat(length(tif_paths), "rasters found\n")

# --- 2. read headers only, build a common template grid ---------------------
rasters <- lapply(tif_paths, rast)

crs_list <- unique(vapply(rasters, function(r) crs(r, describe = TRUE)$code, character(1)))
res_list <- unique(t(vapply(rasters, res, numeric(2))))
if (length(crs_list) > 1) stop("Rasters do not share a common CRS: ", paste(crs_list, collapse = ", "))
if (nrow(res_list) > 1) stop("Rasters do not share a common resolution")

exts <- lapply(rasters, ext)
xmin <- min(vapply(exts, function(e) e$xmin, numeric(1)))
xmax <- max(vapply(exts, function(e) e$xmax, numeric(1)))
ymin <- min(vapply(exts, function(e) e$ymin, numeric(1)))
ymax <- max(vapply(exts, function(e) e$ymax, numeric(1)))
cell_res <- res(rasters[[1]])[1]

template <- rast(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
                  resolution = cell_res, crs = crs(rasters[[1]]))

# sanity check: every raster's origin must align with the template's,
# otherwise cellFromXY below would silently misalign values between layers
for (nm in names(rasters)) {
  o <- origin(rasters[[nm]])
  ot <- origin(template)
  if (any(abs(o - ot) > 1e-6)) {
    stop("Grid origin mismatch for ", nm, ": ", paste(o, collapse = ","),
         " vs template ", paste(ot, collapse = ","))
  }
}

cat("Template grid:", ncol(template), "x", nrow(template),
    "cells, resolution", cell_res, "\n")

# --- 3. extract non-NA cells per raster, keyed by template cell id ----------
extract_layer <- function(nm) {
  r <- rasters[[nm]]
  df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)
  setDT(df)
  setnames(df, 3, nm)
  df[, cell_id := cellFromXY(template, cbind(x, y))]
  df[, c("x", "y") := NULL]
  df
}

cat("Extracting valid cells from each raster...\n")
layer_tables <- lapply(names(rasters), extract_layer)
names(layer_tables) <- names(rasters)

for (nm in names(layer_tables)) {
  cat(sprintf("  %-55s %8d cells\n", nm, nrow(layer_tables[[nm]])))
}

# --- 4. full outer join on cell_id ------------------------------------------
cat("Joining all layers (full outer join on cell_id)...\n")
combined <- Reduce(function(a, b) merge(a, b, by = "cell_id", all = TRUE),
                    layer_tables)
cat("Combined table:", nrow(combined), "rows x", ncol(combined), "cols\n")

# --- 5. attach coordinates ---------------------------------------------------
xy <- xyFromCell(template, combined$cell_id)
combined[, easting := xy[, 1]]
combined[, northing := xy[, 2]]

pts_bng <- vect(combined, geom = c("easting", "northing"), crs = crs(template))
pts_wgs84 <- project(pts_bng, "EPSG:4326")
lonlat <- crds(pts_wgs84)
combined[, lon := lonlat[, 1]]
combined[, lat := lonlat[, 2]]

# --- 6. write outputs ---------------------------------------------------------
parquet_path <- file.path(output_dir, "eei_imed_points.parquet")
gpkg_path <- file.path(output_dir, "eei_imed_points.gpkg")

library(arrow)
write_parquet(combined, parquet_path)
cat("Wrote", parquet_path, "\n")

out_vect <- vect(combined, geom = c("lon", "lat"), crs = "EPSG:4326", keepgeom = FALSE)
writeVector(out_vect, gpkg_path, layer = "eei_imed_points", overwrite = TRUE)
cat("Wrote", gpkg_path, "\n")
