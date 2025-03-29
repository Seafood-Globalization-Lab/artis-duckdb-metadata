# ------------------------------------------------------------------------------------- #
# SUMMARY:
# This R script loads structured seafood trade and production data into a DuckDB database.
# It follows a multi-step process:
#
# 1. Connects to a DuckDB database (creates it if it doesn't exist).
# 2. Creates empty SQL tables with explicitly defined schemas (column names/types must match CSVs).
# 3. Reads CSV and Parquet files, performs type coercion to match SQL schemas exactly.
# 4. Appends the cleaned data into the corresponding SQL tables.
# 5. Builds a detailed metadata table with one row per column, including names, types, and descriptions.
# 6. Safely disconnects from the DuckDB database.
# ------------------------------------------------------------------------------------- #

# -------------------------- #
# Load Libraries & Connect  #
# -------------------------- #
library(arrow)
library(DBI)
library(duckdb)

con <- dbConnect(duckdb::duckdb(), dbdir = "ARTIS_SAU_V0_03-29-2025_w_metadata.duckdb", read_only = FALSE)

# -------------------------- #
# Step 1: Create SQL Tables  #
# -------------------------- #
dbExecute(con, "DROP TABLE IF EXISTS baci;")
dbExecute(con, "CREATE TABLE baci (exporter_iso3c TEXT, importer_iso3c TEXT, hs6 TEXT, product_weight_t DOUBLE, hs_version TEXT, year INTEGER);")

dbExecute(con, "DROP TABLE IF EXISTS code_max_resolved;")
dbExecute(con, "CREATE TABLE code_max_resolved (hs_version TEXT, hs6 TEXT, sciname TEXT, sciname_hs_modified TEXT);")

dbExecute(con, "DROP TABLE IF EXISTS countries;")
dbExecute(con, "CREATE TABLE countries (iso3c TEXT, country_name TEXT, owid_region TEXT, continent TEXT);")

dbExecute(con, "DROP TABLE IF EXISTS products;")
dbExecute(con, "CREATE TABLE products (hs6 TEXT, description TEXT, presentation TEXT, state TEXT);")

sciname_data <- read.csv("sciname.csv")
dbExecute(con, "DROP TABLE IF EXISTS sciname;")
dbWriteTable(con, "sciname", sciname_data[0,])

dbExecute(con, "DROP TABLE IF EXISTS consumption;")
dbExecute(con, "CREATE TABLE consumption (
  source_country_iso3c TEXT, exporter_iso3c TEXT, consumer_iso3c TEXT, consumption_type TEXT,
  sciname TEXT, sciname_hs_modified TEXT, habitat TEXT, method TEXT, dom_source TEXT,
  consumption_t DOUBLE, consumption_t_capped DOUBLE, year INTEGER);")

dbExecute(con, "DROP TABLE IF EXISTS trade;")
dbExecute(con, "CREATE TABLE trade (
  source_country_iso3c TEXT, exporter_iso3c TEXT, importer_iso3c TEXT, hs6 TEXT,
  sciname TEXT, habitat TEXT, method TEXT, dom_source TEXT,
  product_weight_t DOUBLE, live_weight_t DOUBLE, year INTEGER);")

dbExecute(con, "DROP TABLE IF EXISTS metadata;")
dbExecute(con, "CREATE TABLE metadata (
  table_name TEXT, table_description TEXT, column_name TEXT, column_data_type TEXT, column_description TEXT);")

# -------------------------- #
# Step 2: Ingest Data        #
# -------------------------- #

# BACI
d <- read.csv("baci.csv")
d$exporter_iso3c <- as.character(d$exporter_iso3c)
d$importer_iso3c <- as.character(d$importer_iso3c)
d$hs6 <- as.character(d$hs6)
d$hs6 <- ifelse(nchar(d$hs6) == 5, paste0("0", d$hs6), d$hs6)
d$product_weight_t <- as.numeric(d$product_weight_t)
d$hs_version <- as.character(d$hs_version)
d$year <- as.integer(d$year)
dbWriteTable(con, "baci", d, overwrite = TRUE)

# Code Max Resolved
c <- read.csv("code_max_resolved.csv")
c$hs_version <- as.character(c$hs_version)
c$hs6 <- as.character(c$hs6)
c$hs6 <- ifelse(nchar(c$hs6) == 5, paste0("0", c$hs6), c$hs6)
c$sciname <- as.character(c$sciname)
c$sciname_hs_modified <- as.character(c$sciname_hs_modified)
dbWriteTable(con, "code_max_resolved", c, overwrite = TRUE)

# Countries
cn <- read.csv("countries.csv")
cn$iso3c <- as.character(cn$iso3c)
cn$country_name <- as.character(cn$country_name)
cn$owid_region <- as.character(cn$owid_region)
cn$continent <- as.character(cn$continent)
dbWriteTable(con, "countries", cn, overwrite = TRUE)

# Products
p <- read.csv("products.csv")
p$hs6 <- as.character(p$hs6)
p$hs6 <- ifelse(nchar(p$hs6) == 5, paste0("0", p$hs6), p$hs6)
p$description <- as.character(p$description)
p$presentation <- as.character(p$presentation)
p$state <- as.character(p$state)
dbWriteTable(con, "products", p, overwrite = TRUE)

# Sciname
dbWriteTable(con, "sciname", sciname_data, overwrite = TRUE)

# Consumption
cs <- as.data.frame(read_parquet("2024_09_12_SAU_consumption_midpoint.parquet"))
cs$source_country_iso3c <- as.character(cs$source_country_iso3c)
cs$exporter_iso3c <- as.character(cs$exporter_iso3c)
cs$consumer_iso3c <- as.character(cs$consumer_iso3c)
cs$consumption_type <- as.character(cs$consumption_type)
cs$sciname <- as.character(cs$sciname)
cs$sciname_hs_modified <- as.character(cs$sciname_hs_modified)
cs$habitat <- as.character(cs$habitat)
cs$method <- as.character(cs$method)
cs$dom_source <- as.character(cs$dom_source)
cs$consumption_t <- as.numeric(cs$consumption_t)
cs$consumption_t_capped <- as.numeric(cs$consumption_t_capped)
cs$year <- as.integer(cs$year)
dbWriteTable(con, "consumption", cs, overwrite = TRUE)

# Trade
t <- as.data.frame(read_parquet("snet_midpoint_all_hs_all_years.parquet"))
t$source_country_iso3c <- as.character(t$source_country_iso3c)
t$exporter_iso3c <- as.character(t$exporter_iso3c)
t$importer_iso3c <- as.character(t$importer_iso3c)
t$hs6 <- as.character(t$hs6)
t$hs6 <- ifelse(nchar(t$hs6) == 5, paste0("0", t$hs6), t$hs6)
t$sciname <- as.character(t$sciname)
t$habitat <- as.character(t$habitat)
t$method <- as.character(t$method)
t$dom_source <- as.character(t$dom_source)
t$product_weight_t <- as.numeric(t$product_weight_t)
t$live_weight_t <- as.numeric(t$live_weight_t)
t$year <- as.integer(t$year)
dbWriteTable(con, "trade", t, overwrite = TRUE)

# -------------------------- #
# Step 3: Add Metadata       #
# -------------------------- #
make_metadata <- function(table_name, table_description, columns, types, descriptions) {
  data.frame(
    table_name = rep(table_name, length(columns)),
    table_description = rep(table_description, length(columns)),
    column_name = columns,
    column_data_type = types,
    column_description = descriptions,
    stringsAsFactors = FALSE
  )
}

metadata <- rbind(
  make_metadata(
    "baci", "BACI bilateral trade records for all countries in ARTIS for 1996 - 2020",
    c("exporter_iso3c", "importer_iso3c", "hs6", "product_weight_t", "hs_version", "year"),
    c("chr", "chr", "str", "num", "chr", "int"),
    c(
      "ISO3 3-letter code for direct exporter",
      "ISO3 3-letter code for direct importer",
      "HS 6-digit code as string used to identify what product is being traded",
      "Product weight in tonnes",
      "HS code version for the year used",
      "Year trade occurred"
    )
  ),
  make_metadata(
    "code_max_resolved", "Conversion table to resolve a scientific name from higher order taxa to a more specific species based on HS product and HS version",
    c("hs_version", "hs6", "sciname", "sciname_hs_modified"),
    c("chr", "str", "chr", "chr"),
    c(
      "HS code version for the year",
      "HS 6-digit code as string used to identify what product is being traded",
      "Original scientific name determined by production records",
      "More specific/resolved scientific name given HS version and HS product"
    )
  ),
  make_metadata(
    "countries", "Attribute data about countries that contains key identifiers and classifications for each country",
    c("iso3c", "country_name", "owid_region", "continent"),
    c("chr", "chr", "chr", "chr"),
    c(
      "ISO3 3-letter code for country",
      "Country name in English",
      "Country's region as defined by Our World in Data",
      "Country's continent as defined by R countrycode package"
    )
  ),
  make_metadata(
    "products", "Attribute data describing the characteristics of seafood products identified by their HS 6-digit codes",
    c("hs6", "description", "presentation", "state"),
    c("str", "chr", "chr", "chr"),
    c(
      "HS 6-digit product code as string",
      "General description of the product",
      "Product form",
      "Product state"
    )
  ),
  make_metadata(
    "sciname", "Scientific name reference data table (structure inferred from CSV)",
    colnames(sciname_data),
    rep("chr", length(colnames(sciname_data))),
    rep("(Description TBD)", length(colnames(sciname_data)))
  ),
  make_metadata(
    "consumption", "ARTIS consumption estimates from trade",
    c("source_country_iso3c", "exporter_iso3c", "consumer_iso3c", "consumption_type", "sciname", "sciname_hs_modified", "habitat", "method", "dom_source", "consumption_t", "consumption_t_capped", "year"),
    c("chr", "chr", "chr", "chr", "chr", "chr", "chr", "chr", "chr", "num", "dbl", "int"),
    c(
      "ISO3c code for the country that produced",
      "ISO3c code for the final exporter",
      "ISO3c code for the country consuming",
      "Indicator of consumed product origin",
      "Species/species group name",
      "The most resolved version of the species/species group name",
      "Habitat in which species/species group was produced",
      "Defines method of production",
      "Identifies the source for the export",
      "Live weight equivalent consumed per capita thresholded at 100 kg",
      "Live weight equivalent consumed with no per capita threshold",
      "Year in which the apparent consumption took place"
    )
  ),
  make_metadata(
    "trade", "ARTIS trade flows (aka snet)",
    c("source_country_iso3c", "exporter_iso3c", "importer_iso3c", "hs6", "sciname", "habitat", "method", "dom_source", "product_weight_t", "live_weight_t", "year"),
    c("chr", "chr", "chr", "str", "chr", "chr", "chr", "chr", "num", "num", "int"),
    c(
      "ISO3c code for the country that produced",
      "ISO3c code for direct exporter",
      "ISO3c code for direct importer",
      "HS 6-digit code as string",
      "Species/species group name",
      "Habitat in which species/species group was produced",
      "Defines method of production",
      "Identifies the source for the export",
      "Product weight of trade record in tonnes",
      "Live weight equivalent of trade record in tonnes",
      "Year in which trade took place"
    )
  )
)

dbWriteTable(con, "metadata", metadata, overwrite = TRUE)

# -------------------------- #
# Step 4: Disconnect         #
# -------------------------- #
dbDisconnect(con)
