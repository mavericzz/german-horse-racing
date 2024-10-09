library(tidyverse)

# set working directory to directory in which script is stored
script_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_path)

races <- readRDS("../data/processed/engineered_features.Rds")

# hoavgdistbtn: Calculate weighted mean dist_btn_cum for first-time runners in 
# races Ausgleich IV 
hoavgdistbtn_imputation <- races %>% 
  filter(
    date_time < "2021-01-01 01:00:00",  # Use historical data before test set
    date_time > "2003-01-01 01:00:00",  # Optionally exclude very early data
    race_class_old == "Ausgleich IV",   # Focus on the relevant class
    hofirstrace == 1                    # First-time runners only
  ) %>% 
  group_by(year = year(date_time)) %>%   # Group by year
  summarise(
    n = n(),                            # Calculate number of races per year
    mean_distbtncum = mean(dist_btn_cum, na.rm = TRUE)  # Calculate mean
  ) %>% 
  summarise(
    weighted_mean = weighted.mean(mean_distbtncum, w = n)  # Weighted average
  ) %>% 
  pull(weighted_mean)                  # Extract the value

# Impute in the entire dataset
races <- races %>%
  mutate(
    hoavgdistbtn = ifelse(
      is.na(hoavgdistbtn) | is.nan(hoavgdistbtn),  # Check for both NA and NaN
      hoavgdistbtn_imputation,                   # Impute the calculated value
      hoavgdistbtn                              # Otherwise, keep original value
    ),
    hoavgdistbtn_log = log(hoavgdistbtn + 1)
  )




# hodays: If a horse runs its first race hodays will be NA. Impute 0 for those
# cases in Ausgleich IV races
races <- races %>% 
  mutate(
    hodays = ifelse(
      race_class_old == "Ausgleich IV" & hofirstrace == 1 & is.na(hodays),
      0,
      hodays
    )
  )



##----------------- INTERACTION TERMS ----------------------------------------##

races <- races %>% 
  mutate(
    hofirstraceXhoavgdistbtn = hofirstrace * hoavgdistbtn,
    hosr730Xtrsr = hosr730 * trsr,
    hosr730Xjosr = hosr730 * josr,
    hosr730Xhomeanearn = hosr730 * homeanearn
  )


saveRDS(
  races, 
  "../data/processed/imputed_data_for_clogit_agliv.Rds"
)



