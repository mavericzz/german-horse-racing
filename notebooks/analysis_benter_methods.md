Predicting German Horse Race Outcomes using a Benter-Inspired Model
================

- [Introduction](#introduction)
- [1 Horse Racing in Germany](#1-horse-racing-in-germany)
  - [1.1 Betting Market](#11-betting-market)
  - [1.2 Takeout](#12-takeout)
- [2 Bill Benter’s Approach](#2-bill-benters-approach)
- [3 Data](#3-data)
  - [3.1 Description of potential Features for the
    Model](#31-description-of-potential-features-for-the-model)
  - [3.2 Filtering and Preparing the
    Data](#32-filtering-and-preparing-the-data)
  - [3.3 Train and Test Split](#33-train-and-test-split)
- [4 Feature Selection Process via
  AIC](#4-feature-selection-process-via-aic)
- [5 Training and Testing the Model](#5-training-and-testing-the-model)
  - [5.1 Incorporating the Odds and training the
    Model](#51-incorporating-the-odds-and-training-the-model)
  - [5.2 Testing the Model](#52-testing-the-model)
  - [5.3 Outperforming the Market or just a few lucky
    Wins?](#53-outperforming-the-market-or-just-a-few-lucky-wins)
- [6 Conclusion](#6-conclusion)

## Introduction

This notebook explores the application of quantitative methods, inspired
by the legendary horse racing bettor Bill Benter, to the German horse
racing market.

Web-scraped data and a conditional logistic regression model will be
leveraged to estimate the probability of each horse winning a race. The
predictors in the model will be automatically selected by identifying
the set of potential predictors which minimizes the Akaike Information
Criterion on the training dataset. The aim is to identify potential
market inefficiencies and to assess the effectiveness of Benter’s
approach in the context of German horse racing.

``` r
library(data.table)
library(gt)
library(survival)
library(tidyverse)
library(zoo)
```

# 1 Horse Racing in Germany

Germany features two primary types of horse racing: Harness racing and
flat racing. Steeplechasing and hurdling have largely faded into
history.[^1] This notebook will concentrate on flat racing.

## 1.1 Betting Market

Betting plays a crucial role in German horse racing, as a portion of the
prize money is funded by the parimutuel betting operator’s profits.[^2]
Betting in Germany occurs through two primary channels: bookmakers
(fixed odds) and the totalizator (parimutuel). For this analysis, the
focus lies exclusively on parimutuel odds.

The german betting pool sizes are small compared to those in France and
miniscule compared to Hong Kong. On a typical Sunday of racing in
Germany the win pool will seldomly exceed 10,000€. In 2023 the betting
turnover per race across all different pools (win, place, exacta,
trifecta, etc.) averaged 30,396€.[^3]

## 1.2 Takeout

In parimutuel betting, the track retains a commission known as takeout.
In Germany, the takeout for win and place markets is 15%. This analysis
will concentrate solely on the win market.

# 2 Bill Benter’s Approach

Inspired by Bolton and Chapman’s (1986) seminal paper, Bill Benter
employed a conditional logistic regression model to predict horse racing
outcomes in Hong Kong.[^4] His innovative approach incorporated the
public’s estimate, as reflected in betting odds, into his model.[^5]

Bill Benter employed a two-step-approach in incorporating the public
estimate via the odds: At first he estimated his own fundamental model
on one part of the training data. In the next step he estimated a new
model with two predictors, namely the probabilities of his own model and
the public estimate for the win probabilities of each horse, on the
second part of the training data. For both steps he used a conditional
logistic regression.

Following a similar path, we’ll attempt to identify market
inefficiencies within German horse racing.

# 3 Data

This analysis utilizes German horse racing data collected via web
scraping from the official website of Deutscher Galopp e.V. The dataset
encompasses race results, race details, and betting odds spanning from
2002 to the present. However, due to a significantly higher takeout rate
before 2019, only races from 2019 onwards are included in model training
and testing. Data prior to 2019 was leveraged for feature engineering,
drawing inspiration from the work of Bolton and Chapman (1986). The web
scraping process is detailed in the [data_acquisition
folder](../data_acquisition/), while the feature engineering, and data
imputation steps can be found in the [data_processing
folder](../data_processing/). The imputation was necessary on several
occasions because the conditional logistic regression approach can’t
handle missing values. Without imputation the number of races that could
be used would be too low.

``` r
# Import data
races <- readRDS("../data/processed/imputed_data_for_clogit_agliv.Rds")
```

## 3.1 Description of potential Features for the Model

The following set of features used in the automated variable selection
process for the final model were primarily chosen based on existing
literature, common sense, domain expertise in horse racing.

### Horse-related features

- **`hoattend`**: Horse’s experience measured in number of races the
  horse has attended over their career up to the current race, excluding
  the current race itself
- **`hosr730`**: Horse’s strike rate in the last 2 years
- **`hosr`**: Horse’s career strike rate
- **`homean4sprat`**: Horse’s mean speed rating in the last 4 races
- **`homeanearn365`**: Horse’s mean earnings per race in the last 365
  days
- **`holastsprat`**: Horse’s last speed rating
- **`hofirstrace`**: Indicator if it’s the horse’s first race
- **`hodays`**: Number of days since the horse’s last race
- **`gag_turf`**: Horse’s handicap rating on turf before the race
- **`gagindicator_turf`**: Takes the value 1 if the horse’s current
  handicap rating on turf is lower than its rating at the time of its
  most recent win on turf, 0 otherwise
- **`blinkers1sttime`**: Indicator if the horse is wearing blinkers for
  the first time
- **`weight`**: Weight carried by the horse

### Jockey-related features

- **`joattend`**: Number of races a jockey has participated in up to the
  current race
- **`josr365`**: Jockey’s strike rate in the last 365 days before the
  current race
- **`jowins365`**: Number of wins for the jockey in the last 365 days
- **`joam`**: Indicates whether the jockey is an amateur rider (1) or a
  professional jockey (0)

### Trainer-related features

- **`trattend`**: Number of races a trainer has participated in up to
  the current race
- **`trmeanearn`**: Trainer’s average earnings per race up to the
  current race

### Other features

- **`draweffect_median`**: The median estimated disadvantage (in terms
  of lengths) associated with the horse’s starting stall compared to the
  innermost stall

``` r
# Define a vector to store the names of features used subsequently
features <- c(
  # Horse-related features
  "hoattend", "hosr730", "homean4sprat", "homeanearn365", "holastsprat",
  "hofirstrace", "hodays", "gag_turf", "gagindicator_turf", 
  "blinkers1sttime", "weight", 
  
  # Jockey-related features
  "joattend", "josr365", "jowins365", "joam", 
  
  # Trainer-related features
  "trattend", "trmeanearn",
  
  # Other features
  "draweffect_median"
)
```

## 3.2 Filtering and Preparing the Data

This section prepares the data for variable selection, model training,
and prediction. Jump races and stakes races are excluded as the focus is
on flat races and specifically “Ausgleich IV” handicap races. “Ausgleich
IV” races are the lowest class of racing in Germany and those races are
run very frequently with many observations per horse in a year.

Additionally, races before 2019 are removed due to a significantly
different takeout rate at that time. The data is further filtered to
ensure data integrity by removing races with missing odds, homean4sprat
values, or stall numbers. Lastly, races with dead heats are excluded and
the data is sorted by date and time.

``` r
# Finding races with dead heats
dead_heat_races <- races %>% 
  group_by(dg_raceid, position) %>%
  filter(position == 1) %>% 
  summarise(
    position1_count = n(),
    .groups = "drop"
  ) %>%
  filter(position1_count > 1) %>% 
  pull(dg_raceid) 

# Finding races where homean4sprat is missing
homean4sprat_missing_races <- races %>% 
  filter(is.na(homean4sprat)) %>% 
  pull(dg_raceid)

# Finding races where hostall is missing
missing_stall_races <- races %>%  
  filter(is.na(hostall)) %>% 
  pull(dg_raceid)


data <- races %>% 
  # Filter races based on type, class, surface, and date
  filter(
    race_type == "flat",
    race_class_old == "Ausgleich IV",
    surface == "Turf",
    date_time > "2019-01-01 01:00:00"
  ) %>% 
  # Select the necessary columns
  select(
    all_of(
      c(
        features,
        "dg_raceid", "date_time", "win", "dg_horseid", "horse", "hostall", 
        "odds"
      )
    )
  ) %>%
  # Handle missing values and ensure data integrity
  filter(
    !dg_raceid %in% dead_heat_races,
    !dg_raceid %in% homean4sprat_missing_races,
    !dg_raceid %in% missing_stall_races,
    !is.na(odds)
  ) %>% 
  mutate(
    hodays = ifelse(hofirstrace == 1, 0, hodays)
  ) %>% 
  arrange(date_time) %>% 
  group_by(dg_horseid) %>% 
  # For each horse use last measured speed rating if last speedrating is missing
  mutate(holastsprat = na.locf(holastsprat, na.rm = FALSE)) %>% 
  ungroup()
```

## 3.3 Train and Test Split

The dataset is split into a training set and a test set to evaluate the
model’s performance on unseen data. The training set includes races
before January 1, 2021, while the test set contains races from that date
onwards. Variable selection and training will be done on `train_data`
and the performance of the model will be assessed on the `test_data`.

The unusual split ratio of 1:2 (training on one-third of the data and
testing on two-thirds of the data) has been chosen because the
cumulative earnings of employing the model and a simple betting strategy
will be used to measure the model’s performance. Two-thirds of the data
equals roughly 1000 races, which is a good number of races to evaluate
potential betting strategies.

``` r
# Create training dataset using races before 2021
train_data <- data %>% 
  filter(date_time < "2021-01-01 01:00:00")

# Create test dataset using races after 2021
test_data <- data %>% 
  filter(date_time > "2021-01-01 01:00:00") %>% 
  data.table()
```

# 4 Feature Selection Process via AIC

The goal is to automate the feature selection process for the model.
Looking for the feature combination which minimizes the Akaike
information criterion (AIC) on the training set is one possible route in
solving this problem. The `odds` variable should and will be left out at
this stage, because the odds are a very strong predictor for the win
probabilities of each horse. Inclusion of the odds in the variable
selection process could mask important relationships between the other
features and the dependent variable (`win`).

A conditional logistic regression model (`clogit`) is employed to
predict the probability of a horse winning a race. This model is
wellsuited for analyzing data with multiple observations within groups
(horses within races) and allows us to account for the inherent
dependencies within each race. This approach is consistent with Bill
Benter’s strategy in horse race prediction. But in contrast to Benter’s
two-step approach to incorporate the public estimate (the odds), here a
one-step approach is utilized.

It is not publicly known how Benter solved the feature selection
process. But starting with a combination of features which minimize the
AIC seems a reasonable enough approach.

``` r
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
      "lowest_aic: ", as.character(lowest_aic), 
      " best aic: ", as.character(best_aic)
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
```

    ## [1] "lowest_aic:  2415.10300919911  best aic:  Inf"
    ## [1] "Iteration 1 : Selected feature: trmeanearn"
    ## [1] "lowest_aic:  2379.40653470769  best aic:  2415.10300919911"
    ## [1] "Iteration 2 : Selected feature: jowins365"
    ## [1] "lowest_aic:  2350.75053213177  best aic:  2379.40653470769"
    ## [1] "Iteration 3 : Selected feature: homeanearn365"
    ## [1] "lowest_aic:  2327.4462428047  best aic:  2350.75053213177"
    ## [1] "Iteration 4 : Selected feature: draweffect_median"
    ## [1] "lowest_aic:  2312.1138640114  best aic:  2327.4462428047"
    ## [1] "Iteration 5 : Selected feature: homean4sprat"
    ## [1] "lowest_aic:  2302.69206367201  best aic:  2312.1138640114"
    ## [1] "Iteration 6 : Selected feature: joam"
    ## [1] "lowest_aic:  2294.05618950646  best aic:  2302.69206367201"
    ## [1] "Iteration 7 : Selected feature: hodays"
    ## [1] "lowest_aic:  2286.47470899281  best aic:  2294.05618950646"
    ## [1] "Iteration 8 : Selected feature: hoattend"
    ## [1] "lowest_aic:  2284.64224749249  best aic:  2286.47470899281"
    ## [1] "Iteration 9 : Selected feature: josr365"
    ## [1] "lowest_aic:  2283.71627546938  best aic:  2284.64224749249"
    ## [1] "Iteration 10 : Selected feature: hosr730"
    ## [1] "lowest_aic:  2283.07253414899  best aic:  2283.71627546938"
    ## [1] "Iteration 11 : Selected feature: blinkers1sttime"
    ## [1] "lowest_aic:  2282.56727016848  best aic:  2283.07253414899"
    ## [1] "Iteration 12 : Selected feature: holastsprat"
    ## [1] "lowest_aic:  2282.56727016848  best aic:  2282.56727016848"

``` r
# Print the best model summary
summary(best_model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5690L), win) ~ trmeanearn + jowins365 + 
    ##     homeanearn365 + draweffect_median + homean4sprat + joam + 
    ##     hodays + hoattend + josr365 + hosr730 + blinkers1sttime + 
    ##     holastsprat + strata(dg_raceid), data = train_data, method = "exact")
    ## 
    ##   n= 5625, number of events= 524 
    ##    (65 observations deleted due to missingness)
    ## 
    ##                         coef  exp(coef)   se(coef)      z Pr(>|z|)    
    ## trmeanearn         5.081e-04  1.001e+00  7.321e-05  6.939 3.94e-12 ***
    ## jowins365          6.851e-03  1.007e+00  1.825e-03  3.755 0.000173 ***
    ## homeanearn365      8.465e-04  1.001e+00  1.797e-04  4.711 2.46e-06 ***
    ## draweffect_median -2.668e-03  9.973e-01  1.860e-02 -0.143 0.885946    
    ## homean4sprat       1.223e-02  1.012e+00  4.396e-03  2.781 0.005413 ** 
    ## joam              -7.256e-01  4.840e-01  2.226e-01 -3.260 0.001112 ** 
    ## hodays            -2.690e-03  9.973e-01  9.404e-04 -2.861 0.004224 ** 
    ## hoattend          -6.998e-03  9.930e-01  2.554e-03 -2.739 0.006154 ** 
    ## josr365            1.235e+00  3.438e+00  5.935e-01  2.081 0.037442 *  
    ## hosr730           -1.187e+00  3.053e-01  6.817e-01 -1.741 0.081763 .  
    ## blinkers1sttime   -2.805e-01  7.554e-01  1.781e-01 -1.575 0.115210    
    ## holastsprat        4.820e-03  1.005e+00  3.053e-03  1.579 0.114395    
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                   exp(coef) exp(-coef) lower .95 upper .95
    ## trmeanearn           1.0005     0.9995   1.00036    1.0007
    ## jowins365            1.0069     0.9932   1.00328    1.0105
    ## homeanearn365        1.0008     0.9992   1.00049    1.0012
    ## draweffect_median    0.9973     1.0027   0.96163    1.0344
    ## homean4sprat         1.0123     0.9878   1.00362    1.0211
    ## joam                 0.4840     2.0660   0.31291    0.7487
    ## hodays               0.9973     1.0027   0.99548    0.9992
    ## hoattend             0.9930     1.0070   0.98807    0.9980
    ## josr365              3.4382     0.2908   1.07442   11.0027
    ## hosr730              0.3053     3.2758   0.08024    1.1613
    ## blinkers1sttime      0.7554     1.3238   0.53288    1.0709
    ## holastsprat          1.0048     0.9952   0.99884    1.0109
    ## 
    ## Concordance= 0.682  (se = 0.015 )
    ## Likelihood ratio test= 187.9  on 12 df,   p=<2e-16
    ## Wald test            = 176.5  on 12 df,   p=<2e-16
    ## Score (logrank) test = 197.8  on 12 df,   p=<2e-16

The `selected_features` together with the `odds` will be used in the
next step to train our model.

# 5 Training and Testing the Model

## 5.1 Incorporating the Odds and training the Model

This section focuses on incorporating the odds into the model and
training the final conditional logistic regression model. Inclusion of
the odds is done so with the aim to capture the collective wisdom of the
betting market, which can potentially incorporate insider information
and provide a more comprehensive assessment of each horse’s chances.

The following steps outline the model training process:

1.  **Combine Features:** Combine the selected features with the `odds`
    variable to form the final set of predictors.
2.  **Construct Model Formula:** Create the model formula using the
    selected features and `strata(dg_raceid)` term to account for the
    grouped nature of the data.
3.  **Train Model:** Fit the conditional logistic regression model using
    the `clogit` function on the training data.

``` r
# final features: selected_features + odds
final_features <- c(selected_features, "odds")
final_features
```

    ##  [1] "trmeanearn"        "jowins365"         "homeanearn365"    
    ##  [4] "draweffect_median" "homean4sprat"      "joam"             
    ##  [7] "hodays"            "hoattend"          "josr365"          
    ## [10] "hosr730"           "blinkers1sttime"   "holastsprat"      
    ## [13] "odds"

``` r
# Construct the model formula using the selected features and the odds
final_model_formula <- as.formula(
  paste(
    "win",
    paste(
      paste(final_features, collapse = " + "), "strata(dg_raceid)", sep = " + "
    ),
    sep = " ~ "
  )
)
print(final_model_formula)
```

    ## win ~ trmeanearn + jowins365 + homeanearn365 + draweffect_median + 
    ##     homean4sprat + joam + hodays + hoattend + josr365 + hosr730 + 
    ##     blinkers1sttime + holastsprat + odds + strata(dg_raceid)

``` r
# Fit the conditional logistic regression model
final_model <- clogit(final_model_formula, data = train_data, method = "exact")

# Print model summary
summary(final_model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5690L), win) ~ trmeanearn + jowins365 + 
    ##     homeanearn365 + draweffect_median + homean4sprat + joam + 
    ##     hodays + hoattend + josr365 + hosr730 + blinkers1sttime + 
    ##     holastsprat + odds + strata(dg_raceid), data = train_data, 
    ##     method = "exact")
    ## 
    ##   n= 5625, number of events= 524 
    ##    (65 observations deleted due to missingness)
    ## 
    ##                         coef  exp(coef)   se(coef)      z Pr(>|z|)    
    ## trmeanearn         2.452e-04  1.000e+00  7.797e-05  3.145  0.00166 ** 
    ## jowins365          1.597e-03  1.002e+00  1.925e-03  0.829  0.40687    
    ## homeanearn365      1.185e-04  1.000e+00  2.063e-04  0.574  0.56565    
    ## draweffect_median -1.339e-03  9.987e-01  1.903e-02 -0.070  0.94389    
    ## homean4sprat       5.949e-03  1.006e+00  4.504e-03  1.321  0.18659    
    ## joam              -5.613e-01  5.705e-01  2.246e-01 -2.499  0.01245 *  
    ## hodays            -3.726e-04  9.996e-01  8.250e-04 -0.452  0.65153    
    ## hoattend          -5.763e-03  9.943e-01  2.652e-03 -2.173  0.02979 *  
    ## josr365            8.797e-01  2.410e+00  6.709e-01  1.311  0.18979    
    ## hosr730           -9.433e-01  3.893e-01  7.072e-01 -1.334  0.18227    
    ## blinkers1sttime   -2.586e-01  7.721e-01  1.799e-01 -1.438  0.15055    
    ## holastsprat        2.634e-03  1.003e+00  3.114e-03  0.846  0.39760    
    ## odds              -8.347e-02  9.199e-01  8.374e-03 -9.968  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                   exp(coef) exp(-coef) lower .95 upper .95
    ## trmeanearn           1.0002     0.9998   1.00009    1.0004
    ## jowins365            1.0016     0.9984   0.99783    1.0054
    ## homeanearn365        1.0001     0.9999   0.99971    1.0005
    ## draweffect_median    0.9987     1.0013   0.96211    1.0366
    ## homean4sprat         1.0060     0.9941   0.99712    1.0149
    ## joam                 0.5705     1.7530   0.36732    0.8860
    ## hodays               0.9996     1.0004   0.99801    1.0012
    ## hoattend             0.9943     1.0058   0.98910    0.9994
    ## josr365              2.4103     0.4149   0.64709    8.9777
    ## hosr730              0.3893     2.5684   0.09735    1.5571
    ## blinkers1sttime      0.7721     1.2951   0.54274    1.0985
    ## holastsprat          1.0026     0.9974   0.99654    1.0088
    ## odds                 0.9199     1.0871   0.90494    0.9351
    ## 
    ## Concordance= 0.738  (se = 0.013 )
    ## Likelihood ratio test= 352.8  on 13 df,   p=<2e-16
    ## Wald test            = 206.5  on 13 df,   p=<2e-16
    ## Score (logrank) test = 244.4  on 13 df,   p=<2e-16

The estimated coefficients are extracted from the model summary for use
in subsequent predictions on the test data.

``` r
# Extract coefficients from the model summary
coeffs <- as.vector(summary(final_model)$coefficients[, 1])
```

## 5.2 Testing the Model

The performance of the trained model on unseen data will be evaluated by
generating predictions for races in the test set (races after January 1,
2021). Based on these predictions expected values are calculated. A
straightforward betting strategy is to bet on the horse with the highest
positive expected value in a race.

First, the trained model is applied to the test data to generate
predictions.

``` r
predictions <- test_data[
  , prediction := as.matrix(test_data[, ..final_features]) %*% coeffs
]
```

Races in which predictions for some or all of the horses are missing
will be excluded.

``` r
predictions_missing_races <- predictions %>% 
  filter(is.na(prediction)) %>% 
  pull(dg_raceid)

predictions <- predictions %>% 
  filter(!dg_raceid %in% predictions_missing_races)
```

### Identifying Bets

Next, the expected value for each horse based on the model’s predicted
probabilities and the actual betting odds is calculated. The expected
value represents the average profit or loss one can anticipate from a
bet on that horse. The predictions are filtered to identify the horse
with the highest positive expected value in each race, as laid out with
the straightforward betting strategy described above.

``` r
bets <- predictions %>% 
  group_by(dg_raceid) %>% 
  mutate(
    exp_prediction = exp(prediction),
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

total_bets <- nrow(bets)
total_earnings <- sum(bets$earnings)

# Print the results
cat(
  "Total number of bets:", total_bets, "\n",
  "Total earnings:", total_earnings
)
```

    ## Total number of bets: 914 
    ##  Total earnings: 54.9

Over the test period, our strategy identified 914 potentially profitable
bets. Assuming a uniform bet size of €1.00, the strategy would have
generated cumulative earnings of €54.9.

## 5.3 Outperforming the Market or just a few lucky Wins?

The cumulative earnings over the number of bets are plotted to assess
the overall profitability and the pattern of wins and losses over the
test period. The dotted red line represents the expected cumulative
earnings if the horse for the win bet was picked randomly in each race.

``` r
# Calculate expected earnings for each bet (assuming 1 unit bet and 15% takeout)
expected_earnings <- -0.15 * 1:nrow(bets) 

# Create the plot
ggplot(bets, aes(x = 1:nrow(bets))) +  
  geom_line(aes(y = cumulative_earnings)) + 
  geom_line(aes(y = expected_earnings), color = "red", linetype = "dashed") + 
  labs(title = "Cumulative Earnings over Number of Bets",
       x = "Number of Bets",
       y = "Cumulative Earnings") +
  theme_minimal() 
```

![](analysis_benter_methods_files/figure-gfm/unnamed-chunk-14-1.png)<!-- -->

By conducting a bootstrap hypothesis test it is assessed if the observed
earnings are significantly different from what one would expect due to
chance.

``` r
# Set a seed for reproducibility 
set.seed(123) 

# Number of bootstrap replicates
n_bootstraps <- 10000  

# Function to calculate total earnings from a bootstrap sample
calculate_earnings <- function(data, indices) {
  resampled_data <- data[indices, ]
  sum(resampled_data$earnings)
}

# Calculate observed total earnings 
observed_earnings <- sum(bets$earnings) 

# Calculate the expected loss due to takeout 
total_bet_amount <- nrow(bets) 
takeout_rate <- 0.15
expected_loss <- total_bet_amount * takeout_rate

# Perform bootstrapping for actual earnings
boot_results_earnings <- boot::boot(
  data = bets, statistic = calculate_earnings, R = n_bootstraps
)

# Extract the bootstrap distribution of earnings
boot_earnings <- boot_results_earnings$t

# Calculate the p-value (one-sided test)
p_value <- mean(boot_earnings <= -expected_loss)  

# Print the results
cat(
  "Observed Earnings:", observed_earnings, "\n",
  "Expected Loss (with 15% takeout):", expected_loss, "\n",
  "p-value:", p_value, "\n"
)
```

    ## Observed Earnings: 54.9 
    ##  Expected Loss (with 15% takeout): 137.1 
    ##  p-value: 0.0218

The bootstrap hypothesis test yields a p-value of 0.0218. This p-value
is less than the commonly used significance level of 0.05.

The low p-value (0.0218) indicates that the observed earnings of €54.9
are statistically significantly higher than what one would expect if the
betting strategy’s performance were purely due to chance, considering
the 15% takeout.

The bootstrap hypothesis test provides strong evidence that the observed
earnings are not merely due to chance.

``` r
# Create a histogram of the bootstrapped earnings
ggplot(data.frame(earnings = boot_earnings), aes(x = earnings)) + 
  geom_histogram(binwidth = 5, fill = "lightblue", color = "black") +  
  # Add a red vertical line for observed earnings
  geom_vline(xintercept = observed_earnings, color = "red", linetype = "dashed") +
  # Add a blue vertical line for expected loss
  geom_vline(xintercept = -expected_loss, color = "blue", linetype = "dashed") +  
  labs(
    title = "Bootstrap Distribution of Earnings",
    x = "Earnings",
    y = "Frequency"
  ) +
  theme_minimal()
```

![](analysis_benter_methods_files/figure-gfm/unnamed-chunk-16-1.png)<!-- -->

# 6 Conclusion

The trained model demonstrated statistically significant predictive
power, as evidenced by the bootstrap hypothesis test. The cumulative
earnings plot further suggests that the betting strategy based on the
model’s predictions has the potential to generate profits beyond what
would be expected by chance, given the takeout rate.

However, it’s important to acknowledge the limitations of this analysis.
The model was trained and tested on a specific subset of races
(“Ausgleich IV” handicap races on turf), and its performance might not
generalize to other types of races or different market conditions.
Moreover, the betting market is dynamic and subject to fluctuations, so
continued monitoring and adaptation of the strategy would be necessary
for sustained success.

A significant challenge in employing this kind of betting strategy
arises from the nature of parimutuel betting markets. Placing a large
bet on a horse can cause its odds to drop, potentially eliminating any
predicted advantage.

The model could be improved by using cross-validation. Additionally,
developing new and more sophisticated features or trying other methods
like random forests could enhance its predictive power.

[^1]: For a more detailed overview of the different types of horse
    racing, see the [Wikipedia
    article](https://en.wikipedia.org/wiki/Horse_racing#Types_of_horse_racing).

[^2]: For more information on parimutuel betting, see the [Wikipedia
    article](https://en.wikipedia.org/wiki/Parimutuel_betting).

[^3]: As reported by
    [galopponline.de](https://galopponline.de/wetten/wettumsatz-2023-all-time-high-bei-umsatz-je-rennen/#:~:text=Deutscher%20Galopp%20sagt%20dazu%3A%20%E2%80%9EWenngleich,einen%20Rekordwert%20von%2030.396%20Euro.).

[^4]: See Bolton, R.N., & Chapman, R.G.(1986). Searching for positive
    returns at the track: A multinomial logistic regression model for
    handicapping horse races. Management Science, 32(8), pp. 1040-1060.

[^5]: See Benter, W. (1994). Computer-based horse race handicapping and
    wagering systems: A report. In: Efficiency of Racetrack Betting
    Markets, pp. 183-198
