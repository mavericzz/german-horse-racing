library(data.table)
library(survival)
library(zoo)

# set working directory to directory in which script is stored
script_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_path)

# Import data
races <- readRDS("../data/processed/imputed_data_for_clogit_agliv.Rds")


################################################################################
##---------------------------- LIST OF FEATURES ------------------------------##
################################################################################

# Define a vector to store the names of features from which to select the set
# that generates the lowest AIC
features <- c(
  # Horse-related features
  "hosr730", "homean4sprat", "homeanearn365", "holastsprat",
  "hofirstrace", "hodays", "draweffect_median", "gag_turf", "gagindicator_turf", 
  "blinkers1sttime", "weight",
  
  # Jockey-related features
  "josr365", "jowins365", "joam", 
  
  # Trainer-related features
  "trsr"
  
  # Other features

)




################################################################################
##----------------- Filtering and Preparing the Data -------------------------##
################################################################################

# Finding races with dead heats
dead_heat_races <- races  |>  
  group_by(dg_raceid, position) |>
  filter(position == 1) |> 
  summarise(
    position1_count = n(),
    .groups = "drop"
  ) |>
  filter(position1_count > 1) |> 
  pull(dg_raceid) 

# Finding races where homean4sprat is missing
homean4sprat_missing_races <- races |> 
  filter(is.na(homean4sprat)) |> 
  pull(dg_raceid)

# Finding races where hostall is missing
missing_stall_races <- races |>  
  filter(is.na(hostall)) |> 
  pull(dg_raceid)


data <- races |> 
  # Filter races based on type, class, surface, and date
  filter(
    race_type == "flat",
    race_class_old == "Ausgleich IV",
    surface == "Turf",
    date_time > "2019-01-01 01:00:00"
  ) |> 
  # Select the necessary columns
  select(
    all_of(
      c(
        features,
        "dg_raceid", "date_time", "win", "dg_horseid", "horse", "hostall", 
        "odds"
      )
    )
  ) |>
  # Handle missing values and ensure data integrity
  filter(
    !dg_raceid %in% dead_heat_races,
    !dg_raceid %in% homean4sprat_missing_races,
    !dg_raceid %in% missing_stall_races,
    !is.na(odds)
  ) |> 
  mutate(
    hodays = ifelse(hofirstrace == 1, 0, hodays)
  ) |> 
  arrange(date_time) |> 
  group_by(dg_horseid) |> 
  # For each horse use last measured speed rating if last speedrating is missing
  mutate(holastsprat = na.locf(holastsprat, na.rm = FALSE)) |> 
  ungroup()




################################################################################
##------------------------- TRAIN TEST SPLIT ---------------------------------##
################################################################################


# Create training dataset using races before 2021
train_data <- data |> 
  filter(date_time < "2021-01-01 01:00:00")

# Create test dataset using races after 2021
test_data <- data |> 
  filter(date_time > "2021-01-01 01:00:00") |> 
  data.table()



################################################################################
##-------------------- VARIABLE SELECTION WITH AIC ---------------------------##
################################################################################

# Initialize an empty model
best_model <- clogit(win ~ 1 + strata(dg_raceid), data = train_data) 
best_aic <- Inf

# Initialize a vector to store selected features
selected_features <- c()

# Loop through features
for (i in 1:length(features)) {
  
  # Initialize lowest AIC for this iteration
  lowest_aic <- best_aic  
  
  # Loop through remaining features
  # print(setdiff(features, selected_features))
  for (feature in setdiff(features, selected_features)) {
    
    # Create formula with current feature added
    formula <- as.formula(
      paste(
        "win ~", paste(c(selected_features, feature), collapse = " + "), 
        "+ strata(dg_raceid)"
      )
    )
    #print(formula)
    
    # Fit the model
    model <- clogit(formula, data = train_data)
    
    # Check if AIC is lower than current best
    if (AIC(model) < lowest_aic) {
      lowest_aic <- AIC(model)
      best_feature <- feature
    } 
  }
  
  
  print(
    paste(
      "lowest_aic: ", as.character(lowest_aic), " best aic: ", as.character(best_aic)
    )
  )
  if (lowest_aic == best_aic) {
    break
  }
  
  # Add the best feature to the selected features
  selected_features <- c(selected_features, best_feature)
  
  # Update the best model and AIC
  formula <- as.formula(
    paste(
      "win ~", paste(selected_features, collapse = " + "), "+ strata(dg_raceid)"
    )
  )
  best_model <- clogit(formula, data = train_data, method = "exact")
  best_aic <- lowest_aic
  
  # Print the selected feature in this iteration
  print(paste("Iteration", i, ":", "Selected feature:", best_feature))
}

# Print the best model summary
summary(best_model)



################################################################################
##-------------------- FINAL MODEL (ODDS INCLUDED) ---------------------------##
################################################################################

# add odds to selected features
final_features <- c(selected_features, "odds")

# Create formula for final model: best model + odds
final_model_formula <- as.formula(
  paste(
    "win ~", paste(c(final_features), collapse = " + "), 
    "+ odds + strata(dg_raceid)"
  )
)
# Fit model
final_model <- clogit(final_model_formula, data = train_data, method = "exact")
summary(final_model)

# Extract coefficients
coeffs <- as.vector(summary(final_model)$coefficients[, 1])



################################################################################
##--------------------------- CALCULATE PROFITS ------------------------------##
################################################################################

# Calculate the linear predictor
suppressWarnings(
  predictions <- test_data[
    , linear_predictor := as.matrix(test_data[, ..final_features]) %*% coeffs
  ]  
)


# Exclude races if a prediction was not possible
predictions_missing_races <- predictions %>% 
  filter(is.na(linear_predictor)) %>% 
  pull(dg_raceid)
predictions <- predictions %>% 
  filter(!dg_raceid %in% predictions_missing_races)

# Implement betting strategy
bets <- predictions %>% 
  group_by(dg_raceid) %>% 
  mutate(
    exp_prediction = exp(linear_predictor),
    sum_exp_prediction = sum(exp_prediction),
    my_prob = exp_prediction / sum_exp_prediction,
    expected_value = my_prob * (odds - 1) - (1 - my_prob)
  ) %>% 
  filter(
    expected_value > 0,
    expected_value == max(expected_value)
  )  %>% 
  ungroup() %>% 
  arrange(date_time) %>% 
  mutate(
    earnings = ifelse(
      win == 1, odds - 1, -1
    ),
    cumulative_earnings = cumsum(earnings)
  )

# Extract results of betting strategy
total_bets <- nrow(bets)
total_earnings <- sum(bets$earnings)
# Print the results
cat(
  "Total number of bets:", total_bets, "\n",
  "Total earnings:", total_earnings
)


