# german-horse-racing Documentation

This repository contains code and data for predicting the outcomes of German horse races using a quantitative model inspired by the methods of Bill Benter.

## Requirements

* Python 3
* R with the following packages: data.table, survival, tidyverse, zoo

## Data Acquisition

* `dg_fetch_raceinfos.py`: Downloads race details such as date, time, track, distance, etc.
* `dg_fetch_raceresults.py`: Downloads race results, including finishing positions, and odds.

## Data Preprocessing

* `combine_data.R`: Merges the race details and race results data into a single dataset.

## Data Cleaning

* `clean_data.R`: Cleans the data by handling missing values, removing duplicates, and correcting inconsistencies.

## Feature Engineering

* `feature_engineering.R`:  Constructs new variables based on the raw data, such as horse speed figures, jockey statistics, etc.

## Model and Analysis

* `analysis_benter_methods.Rmd`:  Performs the statistical analysis, including model training, feature selection, and evaluation. This file also generates the final report and visualizations.

## Data

The data is sourced from the official website of Deutscher Galopp e.V. The raw data files are stored in the `data/raw` directory. The preprocessed data is saved in the `data/intermediate` diretory. The processed and engineered data is saved in the `data/processed` directory.

## Running the Code

1. Run the Python scripts (`dg_fetch_raceinfos.py` and `dg_fetch_raceresults.py`) to download the data.
2. Run the R scripts (`combine_data.R`, `clean_data.R`, `feature_engineering.R`) in order to process and prepare the data for analysis.
3. Open and run the `analysis_benter_methods.Rmd` file to perform the analysis and generate the report.
