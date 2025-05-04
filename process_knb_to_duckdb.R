# ---- Auto-install and load required packages ----
#' @importFrom utils install.packages
required_packages <- c("dataone", "datapack", "duckdb", "arrow", "tools")

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

invisible(lapply(required_packages, install_if_missing))

# Load libraries
library(dataone)
library(datapack)
library(duckdb)
library(arrow)
library(tools)

#' Process KNB Resource Map and Build DuckDB Database
#'
#' Downloads files from a KNB resource map, unzips them, and builds a DuckDB database
#' from CSV and Parquet files. Includes a metadata table describing all ingested tables.
#'
#' @param resource_map_id Character. KNB resource map identifier (e.g., "resource_map_urn:uuid:...").
#' @param duckdb_name Character. Name of the DuckDB database file to create. Default is "ARTIS_SAU.duckdb".
#' @param timeout_seconds Numeric. Download timeout in seconds. Default is 600.
#' @param wait_minutes Numeric. Pause after download before DB build (in minutes). Default is 1.
#'
#' @return No return value. A DuckDB database is written to disk.
#' @export
process_knb_to_duckdb <- function(resource_map_id,
                                  duckdb_name = "ARTIS_SAU.duckdb",
                                  timeout_seconds = 600,
                                  wait_minutes = 1) {
  options(timeout = timeout_seconds)
  download_dir <- "~/Downloads/artis_downloads"
  download_from_knb(resource_map_id, download_dir)
  unzip_all_files(download_dir)
  Sys.sleep(wait_minutes * 60)
  create_duckdb_from_files(download_dir, duckdb_name)
  message("✅ DuckDB created at ", duckdb_name)
}

#' Download Data Files from KNB
#'
#' Downloads files from a specified KNB resource map. Files smaller than 50MB use the DataONE API;
#' larger files use HTTP.
#'
#' @param resource_map_id Character. The KNB resource map identifier.
#' @param local_path Character. Path to store downloaded files.
#'
#' @return No return value. Files are saved to disk.
#' @keywords internal
download_from_knb <- function(resource_map_id, local_path) {
  cn <- CNode("PROD")
  mn <- getMNode(cn, "urn:node:KNB")

  query_list <- list(
    q = paste0('resourceMap:"', resource_map_id, '"'),
    fl = "identifier,fileName,formatType,formatId,title,size",
    rows = "100"
  )

  result <- query(mn, solrQuery = query_list)
  if (!dir.exists(local_path)) dir.create(local_path, recursive = TRUE)

  small_files <- list()
  large_files <- list()

  for (i in seq_along(result)) {
    size_bytes <- as.numeric(result[[i]]$size)
    file_info <- list(
      identifier = result[[i]]$identifier,
      fileName = result[[i]]$fileName,
      size = size_bytes
    )
    if (size_bytes < 50e6) small_files[[length(small_files)+1]] <- file_info
    else large_files[[length(large_files)+1]] <- file_info
  }

  for (f in small_files) {
    tryCatch({
      file_raw <- getObject(mn, f$identifier)
      filename <- ifelse(is.null(f$fileName) || f$fileName == "", paste0(f$identifier, ".dat"), f$fileName)
      filepath <- file.path(local_path, filename)
      writeBin(file_raw, filepath)
    }, error = function(e) {
      cat("❌ Failed to download (API):", f$fileName, "Error:", e$message, "\n")
    })
  }

  for (f in large_files) {
    tryCatch({
      url <- paste0("https://knb.ecoinformatics.org/knb/d1/mn/v2/object/", f$identifier)
      filename <- ifelse(is.null(f$fileName) || f$fileName == "", paste0(f$identifier, ".dat"), f$fileName)
      filepath <- file.path(local_path, filename)
      download.file(url, destfile = filepath, mode = "wb", quiet = TRUE)
    }, error = function(e) {
      cat("❌ Failed to download (HTTP):", f$fileName, "Error:", e$message, "\n")
    })
  }
}

#' Unzip All ZIP Files in a Directory
#'
#' Unzips all `.zip` files found in a given folder into that same folder.
#'
#' @param local_path Character. Directory containing zip files.
#'
#' @return No return value. Files are extracted in place.
#' @keywords internal
unzip_all_files <- function(local_path) {
  zip_files <- list.files(local_path, pattern = "\\.zip$", full.names = TRUE)
  for (zip_file in zip_files) {
    unzip(zip_file, exdir = local_path)
  }
}

#' Create a DuckDB Database from Data Files
#'
#' Loads CSV and Parquet data from a directory and writes it to a DuckDB file.
#' Includes a metadata table summarizing the loaded tables.
#'
#' @param folder Character. Path to the folder containing input files.
#' @param db_path Character. Output DuckDB file path.
#'
#' @return No return value. DuckDB file is written to disk.
#' @keywords internal
create_duckdb_from_files <- function(folder, db_path) {
  con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)

  read_csv_safe <- function(name) {
    path <- file.path(folder, paste0(name, ".csv"))
    if (file.exists(path)) read.csv(path) else NULL
  }

  read_parquet_safe <- function(name) {
    path <- list.files(folder, pattern = paste0(name, ".*\\.parquet$"), full.names = TRUE)
    if (length(path) == 0) return(NULL)
    return(as.data.frame(arrow::read_parquet(path[1])))
  }

  files <- c("baci", "code_max_resolved", "countries", "products", "sciname")
  for (f in files) {
    df <- read_csv_safe(f)
    if (!is.null(df)) dbWriteTable(con, f, df, overwrite = TRUE)
  }

  df <- read_parquet_safe("consumption")
  if (!is.null(df)) dbWriteTable(con, "consumption", df, overwrite = TRUE)

  df <- read_parquet_safe("trade")
  if (!is.null(df)) dbWriteTable(con, "trade", df, overwrite = TRUE)

  metadata <- data.frame(
    table_name = c("trade", "consumption", "baci", "code_max_resolved", "countries", "products", "sciname"),
    table_description = c(
      "ARTIS trade flows",
      "Consumption estimates",
      "BACI bilateral trade",
      "Taxonomic resolution table",
      "Country info",
      "Product info",
      "Scientific names"
    )
  )
  dbWriteTable(con, "metadata", metadata, overwrite = TRUE)

  dbDisconnect(con)
}
