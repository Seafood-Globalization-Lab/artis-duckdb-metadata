# Load necessary R libraries: 'arrow' for data handling and 'duckdb' for database interactions.
library(arrow)
library(duckdb)

# Establish a connection to a DuckDB database located in the current directory. This connection allows for data modification as 'read_only' is set to FALSE.
con <- dbConnect(duckdb::duckdb(), dbdir = "ARTIS_SAU_V0_03-08-2025_w_metadata.duckdb", read_only = FALSE)

# Import Baci data from a CSV file and set the appropriate data types for each column.
baci_data <- read.csv("baci.csv")
baci_data$exporter_iso3c <- as.character(baci_data$exporter_iso3c)
baci_data$importer_iso3c <- as.character(baci_data$importer_iso3c)
baci_data$hs6 <- as.character(baci_data$hs6) # Read hs6 codes as characters to facilitate manipulation
baci_data$product_weight_t <- as.numeric(baci_data$product_weight_t)
baci_data$hs_version <- as.character(baci_data$hs_version)
baci_data$year <- as.integer(baci_data$year)

# Standardize hs6 codes to 6 digits by prepending zeros where necessary. This is critical for consistency in database queries.
baci_data$hs6 <- ifelse(nchar(baci_data$hs6) == 5, paste0("0", baci_data$hs6), baci_data$hs6)
dbWriteTable(con, "baci", baci_data, overwrite = TRUE) # Write the formatted data to the database, replacing existing table.
head(baci_data, 10) # Display the first 10 rows of the adjusted data for verification.

# Code max resolved table: Load data, adjust data types, and ensure hs6 codes are consistent.
code_max_resolved_data <- read.csv("code_max_resolved.csv")
code_max_resolved_data$hs_version <- as.character(code_max_resolved_data$hs_version)
code_max_resolved_data$hs6 <- as.character(code_max_resolved_data$hs6)
code_max_resolved_data$sciname <- as.character(code_max_resolved_data$sciname)
code_max_resolved_data$sciname_hs_modified <- as.character(code_max_resolved_data$sciname_hs_modified)
code_max_resolved_data$hs6 <- ifelse(nchar(code_max_resolved_data$hs6) == 5, paste0("0", code_max_resolved_data$hs6), code_max_resolved_data$hs6)
dbWriteTable(con, "code_max_resolved", code_max_resolved_data, overwrite = TRUE) # Replace existing table with new data.

# Countries table: Load and format data, ensuring all textual data remains in character format for consistency.
countries_data <- read.csv("countries.csv")
countries_data$iso3c <- as.character(countries_data$iso3c)
countries_data$country_name <- as.character(countries_data$country_name)
countries_data$owid_region <- as.character(countries_data$owid_region)
countries_data$continent <- as.character(countries_data$continent)
dbWriteTable(con, "countries", countries_data, overwrite = TRUE) # Overwrite existing countries table with updated data.

# Products table: Import data, convert data types, and adjust hs6 codes as previously described.
products_data <- read.csv("products.csv")
products_data$hs6 <- as.character(products_data$hs6)
products_data$description <- as.character(products_data$description)
products_data$presentation <- as.character(products_data$presentation)
products_data$state <- as.character(products_data$state)
products_data$hs6 <- ifelse(nchar(products_data$hs6) == 5, paste0("0", products_data$hs6), products_data$hs6)
dbWriteTable(con, "products", products_data, overwrite = TRUE)

# Sciname table: Load and write the data directly to the database without modifications.
sciname_data <- read.csv("sciname.csv")
dbWriteTable(con, "sciname", sciname_data, overwrite = TRUE)

# Consumption table: Load data from a Parquet file, convert to DataFrame, and set appropriate data types.
consumption_data <- arrow::read_parquet("2024_09_12_SAU_consumption_midpoint.parquet")
consumption_data <- as.data.frame(consumption_data) # Convert to DataFrame to use with DuckDB.
consumption_data$source_country_iso3c <- as.character(consumption_data$source_country_iso3c)
consumption_data$exporter_iso3c <- as.character(consumption_data$exporter_iso3c)
consumption_data$consumer_iso3c <- as.character(consumption_data$consumer_iso3c)
consumption_data$consumption_type <- as.character(consumption_data$consumption_type)
consumption_data$sciname <- as.character(consumption_data$sciname)
consumption_data$sciname_hs_modified <- as.character(consumption_data$sciname_hs_modified)
consumption_data$habitat <- as.character(consumption_data$habitat)
consumption_data$method <- as.character(consumption_data$method)
consumption_data$dom_source <- as.character(consumption_data$dom_source)
consumption_data$consumption_t <- as.numeric(consumption_data$consumption_t)
consumption_data$consumption_t_capped <- as.double(consumption_data$consumption_t_capped)
consumption_data$year <- as.integer(consumption_data$year)
dbWriteTable(con, "consumption", consumption_data, overwrite = TRUE)

# Trade table: Similar process as consumption, adjusting data types and ensuring hs6 codes are standardized.
trade_data <- arrow::read_parquet("snet_midpoint_all_hs_all_years.parquet")
trade_data <- as.data.frame(trade_data)
trade_data$source_country_iso3c <- as.character(trade_data$source_country_iso3c)
trade_data$exporter_iso3c <- as.character(trade_data$exporter_iso3c)
trade_data$importer_iso3c <- as.character(trade_data$importer_iso3c)
trade_data$hs6 <- as.character(trade_data$hs6)
trade_data$sciname <- as.character(trade_data$sciname)
trade_data$habitat <- as.character(trade_data$habitat)
trade_data$method <- as.character(trade_data$method)
trade_data$dom_source <- as.character(trade_data$dom_source)
trade_data$product_weight_t <- as.numeric(trade_data$product_weight_t)
trade_data$live_weight_t <- as.numeric(trade_data$live_weight_t)
trade_data$year <- as.integer(trade_data$year)
trade_data$hs6 <- ifelse(nchar(trade_data$hs6) == 5, paste0("0", trade_data$hs6), trade_data$hs6)
dbWriteTable(con, "trade", trade_data, overwrite = TRUE)


# Creating metadata table
metadata <- data.frame(
  table_name = c("trade", "consumption", "production", "production_sau", "baci", "code_max_resolved_taxa", "countries", "products"),
  table_description = c(
    "ARTIS trade flows (aka snet)",
    "ARTIS consumption estimates from trade",
    "FAO production records for all countries in ARTIS for 1996 - 2020",
    "All SAU production records for all countries in ARTIS for 1996 - 2019. Note all production is marine capture",
    "BACI bilateral trade records for all countries in ARTIS for 1996 - 2020",
    "Conversion table to resolve a scientific name from higher order taxa to a more specific species based on HS product and HS version",
    "Attribute data about countries that contains key identifiers and classifications for each country",
    "Attribute data describing the characteristics of seafood products identified by their HS 6-digit codes"
  ),
  column_name = c(
    "source_country_iso3c, exporter_iso3c, importer_iso3c, hs6, sciname, habitat, method, dom_source, product_weight_t, live_weight_t, year",
    "source_country_iso3c, exporter_iso3c, consumer_iso3c, consumption_type, sciname, sciname_hs_modified, habitat, method, dom_source, consumption_live_t, original_consumption_live_t, year",
    "iso3c, sciname, method, habitat, live_weight_t, year",
    "country_name_en, country_iso3_alpha, country_iso3_numeric, eez, sector, sciname, year, live_weight_t",
    "exporter_iso3c, importer_iso3c, hs6, product_weight_t, hs_version, year",
    "hs_version, hs6, sciname, sciname_hs_modified",
    "iso3c, country_name, owid_region, continent",
    "hs6, description, presentation, state"
  ),
  column_data_type = c(
    "chr, chr, chr, str, chr, chr, chr, chr, num, num, int",
    "chr, chr, chr, chr, chr, int, chr, chr, chr, num, dbl, int",
    "chr, chr, chr, chr, num, int",
    "chr, chr, int, chr, chr, chr, int, num",
    "chr, chr, str, num, chr, int",
    "chr, str, chr, chr",
    "chr, chr, chr, chr",
    "str, chr, chr, chr"
  ),
  column_description = c(
    "ISO3c code for the country that produced, ISO3c code for direct exporter, ISO3c code for direct importer, HS 6-digit code as string, Species/species group name, Habitat in which species/species group was produced, Defines method of production, Identifies the source for the export, Product weight of trade record in tonnes, Live weight equivalent of trade record in tonnes, Year in which trade took place",
    "ISO3c code for the country that produced, ISO3c code for the final exporter, ISO3c code for the country consuming, Indicator of consumed product origin, Species/species group name, The most resolved version of the species/species group name, Habitat in which species/species group was produced, Defines method of production, Identifies the source for the export, Live weight equivalent consumed per capita thresholded at 100 kg, Live weight equivalent consumed with no per capita threshold, Year in which the apparent consumption took place",
    "ISO3 code for the producing country, Species produced, Defines method of production, Habitat in which species/species group was produced, Live weight in tonnes, Year species was produced",
    "Producing country name in English, Producing country ISO3 3-letter code, Producing country ISO3 numeric code, Exclusive Economic Zone, Economic sector, Species produced, Year species was produced, Live weight in tonnes",
    "ISO3 3-letter code for direct exporter, ISO3 3-letter code for direct importer, HS 6-digit code as string used to identify what product is being traded, Product weight in tonnes, HS code version for the year used, Year trade occurred",
    "HS code version for the year, HS 6-digit code as string used to identify what product is being traded, Original scientific name determined by production records, More specific/resolved scientific name given HS version and HS product",
    "ISO3 3-letter code for country, Country name in English, Country's region as defined by Our World in Data, Country's continent as defined by R countrycode package",
    "HS 6-digit product code as string, General description of the product, Product form, Product state"
  )
)

# Writing the metadata table to DuckDB
dbWriteTable(con, "metadata", metadata, overwrite = TRUE)

# Disconnect from the DuckDB database to free up resources and finalize changes.
dbDisconnect(con)
