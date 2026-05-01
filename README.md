# Energy Consumption Prediction Analysis

Predicting residential energy consumption in South Carolina under a future climate scenario (+5 °C summer temperatures), using one month (July 2018) of hourly per-building energy data merged with static house attributes and county-level weather.

Final project for **Intro to Data Science**.

## Project overview

The goal is to estimate how much additional energy the South Carolina residential grid would draw during a hotter summer. We:

1. Pull hourly energy use per building, static house metadata, and county weather from a public S3 bucket.
2. Merge them into a single hourly panel and aggregate to daily totals per building.
3. Identify which house attributes drive consumption (ANOVA + linear-model significance tests).
4. Train predictive models (linear regression, random forest, ARIMA with temperature as an exogenous regressor).
5. Re-score the data with `mean_temperature + 5 °C` to simulate a future summer and surface the change through a Shiny app.

## Data sources

All inputs are public files hosted at `intro-datascience.s3.us-east-2.amazonaws.com/SC-data/`:

| File | Description |
| --- | --- |
| `static_house_info.parquet` | One row per building — square footage, lighting type, insulation, appliances, occupants, income bracket, lat/lon, etc. |
| `2023-houseData/<bldg_id>.parquet` | Hourly end-use load (42 columns) per building. Filtered to 2018-07-01 → 2018-07-31. |
| `weather/2023-weather-data/<county>.csv` | Hourly weather per SC county (dry-bulb temp, humidity, wind, radiation). |

`reduced_bldg_ids_per_county.csv` (in this repo) lists the building IDs sampled per county.

## Repository contents

| File | Purpose |
| --- | --- |
| `InitialMergeCode (1).R` | Downloads per-building energy and per-county weather, sums the 42 end-use columns into `total_energy_usage`, merges with `static_house_info`, and writes the combined July 2018 dataset. |
| `LinearANOVANeuralNetworks_final.Rmd` | ANOVA over every factor variable to flag significant predictors; fits a linear regression on the daily-aggregated panel; produces a `+5 °C` future-prediction CSV. |
| `RandomForestAndTimeSeriesModel_final.Rmd` | Random Forest (`ntree=500`, `mtry=3`) reaching **R² ≈ 0.927** / RMSE ≈ 3.6 on a held-out 20 % split, plus a per-county ARIMA forecast using temperature as an external regressor. |
| `app (1).R` | Shiny app — pick a county (or "All Counties"), plot present vs. future daily energy, surface the peak day for each. |
| `reduced_bldg_ids_per_county.csv` | Building-ID-to-county mapping used for the reduced sample. |
| `Final Project Report- Intro to Data Science.docx` | Written report. |
| `Final Presentation - Intro to Data Science (1).pptx` | Slide deck. |
| `Final Shiny App Working Video- Intro to Data Science.mp4` | Recorded app demo. |
| `Update on Random forest.docx` | Mid-project update on the RF results. |

## Methodology

**1. Data assembly** (`InitialMergeCode (1).R`)
- Loop every `bldg_id` in `static_house_info`, fetch its hourly Parquet, slice to July 2018, sum the 42 end-use columns into `total_energy_usage`.
- Loop every unique county code, fetch hourly weather, slice to July 2018.
- Left-join energy ⨝ house (on `bldg_id`) and then ⨝ weather (on `in.county` + timestamp).

**2. Feature selection**
- One-way ANOVA of `total_energy_usage` against every factor column at α = 0.05; keep the significant ones.
- Linear regression on the daily panel (`total_energy ~ .`); keep coefficients with `Pr(>|t|) < 0.005`.

**3. Modeling** — three approaches on an 80/20 split:
- **Linear regression** — interpretable baseline; predictions exported to `future_predictions_LM.csv`.
- **Random Forest** — best point estimator (R² ≈ 0.927).
- **ARIMA per county** with average temperature as `xreg` — for hourly forecasts.

**4. Future scenario**
- Add `+5 °C` to `mean_temperature` (or hourly temperature for the time-series model) and re-score each model. Outputs feed the Shiny app.

## Reproducing the analysis

You will need R (≥ 4.0) with: `tidyverse`, `arrow`, `data.table`, `lubridate`, `caret`, `randomForest`, `forecast`, `hts`, `xts`, `kernlab`, `rio`, `rlang`, `shiny`, `ggplot2`.

```r
install.packages(c(
  "tidyverse", "arrow", "data.table", "lubridate", "caret",
  "randomForest", "forecast", "hts", "xts", "kernlab", "rio",
  "rlang", "shiny", "ggplot2"
))
```

Then, in order:

1. Run `InitialMergeCode (1).R` — produces the merged July 2018 dataset (the script's `write.csv` line is commented out; uncomment and point it at a local path).
2. Knit `LinearANOVANeuralNetworks_final.Rmd` — produces `future_predictions_LM.csv`.
3. Knit `RandomForestAndTimeSeriesModel_final.Rmd` — produces `future_predictions.csv` and the per-county ARIMA forecasts.
4. Launch the Shiny app:
   ```r
   shiny::runApp("app (1).R")
   ```

## Results

- Random Forest is the strongest model on this dataset: **R² ≈ 0.927**, RMSE ≈ 3.6 on the held-out test set.
- Top drivers of consumption (from ANOVA + RF importance): square footage, cooling setpoint, lighting type, insulation, occupants, and income bracket.
- Under the `+5 °C` scenario, daily county-level energy demand rises across the board; the Shiny app surfaces both the daily curve and the peak day per county.
