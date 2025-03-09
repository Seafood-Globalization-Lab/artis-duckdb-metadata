# MAU DuckDB Creation Guide

## Overview
This repository contains scripts for generating DuckDB databases tailored for ARTIS model data:
- **MAU_Duckdb_Creation.Rmd**: Generates a DuckDB database without metadata.
- **MAU_Duckdb_Creation_w_metadata.Rmd**: Generates a DuckDB database with metadata.

## Column Descriptions and Data Types
Column specifications are based on the [ARTIS Database Tables](https://github.com/Seafood-Globalization-Lab/artis-model/wiki/ARTIS-Database-Tables). Metadata info has been taken from here. Discrepancies between table descriptions and source files are noted.

## Notable Discrepancies
- **Table: `consumption`**
  - **Description Name**: `consumption_live_t`
  - **Source File Name**: `consumption_t`
  - **Description Name**: `original_consumption_live_t`
  - **Source File Name**: `consumption_t_capped`

## Data Type Considerations
- The `hs6` code is described as an integer in the GitHub table specifications but is stored as a string in the DuckDB to preserve leading zeros.

## Repository Structure
- `MAU_Duckdb_Creation.Rmd`: Script for DuckDB generation without metadata.
- `MAU_Duckdb_Creation_w_metadata.Rmd`: Script for DuckDB generation with metadata.
