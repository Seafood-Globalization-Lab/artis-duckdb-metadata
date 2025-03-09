# SAU DuckDB Creation Guide

## Overview
This repository contains scripts for generating DuckDB databases tailored for ARTIS model data:
- **SAU_Duckdb_Creation_w_metadata.Rmd**: Generates a DuckDB database with metadata (non EML format).

## Column Descriptions and Data Types
Column specifications are sourced from the [ARTIS Database Tables](https://github.com/Seafood-Globalization-Lab/artis-model/wiki/ARTIS-Database-Tables). Metadata is based on these specifications. Discrepancies between table descriptions and source files are noted.

## Notable Discrepancies
- **Table: `consumption`**
  - **Description Name**: `consumption_live_t`
  - **Source File Name**: `consumption_t`
  - **Description Name**: `original_consumption_live_t`
  - **Source File Name**: `consumption_t_capped`

## Data Type Considerations
- The `hs6` code is described as an integer in the GitHub table specifications but is stored as a string in the DuckDB to preserve leading zeros.

## Repository Structure
- `SAU_Duckdb_Creation_w_metadata.Rmd`: Script for DuckDB generation with metadata.

## Generating the SAU DuckDB File
To generate the SAU DuckDB:
1. Download the `SAU_Duckdb_Creation_w_metadata.Rmd` script from [this task page](https://github.com/Seafood-Globalization-Lab/artis-duckdb-metadata/issues/1).
2. Place all required input files in the same location.
3. Rename the DuckDB file according to your requirements, ensuring all files, including the DuckDB file, are located in the same directory.
4. Run the R script to generate the DuckDB in the specified path.
