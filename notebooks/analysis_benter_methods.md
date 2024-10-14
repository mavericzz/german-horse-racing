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

- **`hosr730`**: Horse’s strike rate in the last 2 years
- **`hosr`**: Horse’s career strike rate
- **`homean4sprat`**: Horse’s mean speed rating in the last 4 races
- **`homeanearn365`**: Horse’s mean earnings per race in the last 365
  days
- **`holastsprat`**: Horse’s last speed rating
- **`hofirstrace`**: Indicator if it’s the horse’s first race
- **`hodays`**: Number of days since the horse’s last race
- **`draweffect_median`**: The median estimated disadvantage (in terms
  of lengths) associated with the horse’s starting stall compared to the
  innermost stall
- **`gag`**: Horse’s handicap rating before the race
- **`gagindicator`**: Takes the value 1 if the horse’s current handicap
  rating is lower than its rating at the time of its most recent win, 0
  otherwise
- **`blinkers1sttime`**: Indicator if the horse is wearing blinkers for
  the first time
- **`weight`**: Weight carried by the horse

### Jockey-related features

- **`josr365`**: Jockey’s strike rate in the last 365 days
- **`jowins365`**: Number of wins for the jockey in the last 365 days

### Trainer-related features

- **`trsr`**: Trainer’s strike rate

### Other features

- **`odds`**: Betting odds for the horse

``` r
# Define a vector to store the names of features used in the model
features <- c(
  # Horse-related features
  "hoattend", "hosr730", "homean4sprat", "homeanearn365", "holastsprat",
  "hofirstrace", "hodays", "draweffect_median", "gag_turf", "gagindicator_turf", 
  "blinkers1sttime", "weight", "hohcpclassdrop", "honetgag",
  
  # Jockey-related features
  "joattend", "josr365", "jowins365", "joam", 
  
  # Trainer-related features
  "trattend", "trsr", "trmeanearn"
  
  # Other features

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
selection process could mask important relations between the other
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

    ## [1] "lowest_aic:  2412.54249047461  best aic:  Inf"
    ## [1] "Iteration 1 : Selected feature: trsr"
    ## [1] "lowest_aic:  2379.76113729251  best aic:  2412.54249047461"
    ## [1] "Iteration 2 : Selected feature: jowins365"
    ## [1] "lowest_aic:  2353.16303918151  best aic:  2379.76113729251"
    ## [1] "Iteration 3 : Selected feature: draweffect_median"
    ## [1] "lowest_aic:  2328.63687320376  best aic:  2353.16303918151"
    ## [1] "Iteration 4 : Selected feature: homean4sprat"
    ## [1] "lowest_aic:  2315.41197900729  best aic:  2328.63687320376"
    ## [1] "Iteration 5 : Selected feature: homeanearn365"
    ## [1] "lowest_aic:  2305.20329444784  best aic:  2315.41197900729"
    ## [1] "Iteration 6 : Selected feature: trmeanearn"
    ## [1] "lowest_aic:  2295.88122735889  best aic:  2305.20329444784"
    ## [1] "Iteration 7 : Selected feature: joam"
    ## [1] "lowest_aic:  2287.1375222558  best aic:  2295.88122735889"
    ## [1] "Iteration 8 : Selected feature: hodays"
    ## [1] "lowest_aic:  2281.15656717304  best aic:  2287.1375222558"
    ## [1] "Iteration 9 : Selected feature: hoattend"
    ## [1] "lowest_aic:  2278.78227612658  best aic:  2281.15656717304"
    ## [1] "Iteration 10 : Selected feature: hosr730"
    ## [1] "lowest_aic:  2277.43296384337  best aic:  2278.78227612658"
    ## [1] "Iteration 11 : Selected feature: blinkers1sttime"
    ## [1] "lowest_aic:  2276.25779283767  best aic:  2277.43296384337"
    ## [1] "Iteration 12 : Selected feature: josr365"
    ## [1] "lowest_aic:  2275.73369004857  best aic:  2276.25779283767"
    ## [1] "Iteration 13 : Selected feature: holastsprat"
    ## [1] "lowest_aic:  2275.73369004857  best aic:  2275.73369004857"

``` r
# Print the best model summary
summary(best_model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5690L), win) ~ trsr + jowins365 + 
    ##     draweffect_median + homean4sprat + homeanearn365 + trmeanearn + 
    ##     joam + hodays + hoattend + hosr730 + blinkers1sttime + josr365 + 
    ##     holastsprat + strata(dg_raceid), data = train_data, method = "exact")
    ## 
    ##   n= 5625, number of events= 524 
    ##    (65 observations deleted due to missingness)
    ## 
    ##                         coef  exp(coef)   se(coef)      z Pr(>|z|)    
    ## trsr               4.650e+00  1.046e+02  1.543e+00  3.014 0.002578 ** 
    ## jowins365          6.465e-03  1.006e+00  1.825e-03  3.543 0.000396 ***
    ## draweffect_median -2.296e-03  9.977e-01  1.867e-02 -0.123 0.902114    
    ## homean4sprat       1.214e-02  1.012e+00  4.410e-03  2.752 0.005917 ** 
    ## homeanearn365      8.584e-04  1.001e+00  1.795e-04  4.783 1.73e-06 ***
    ## trmeanearn         2.993e-04  1.000e+00  1.018e-04  2.940 0.003279 ** 
    ## joam              -7.220e-01  4.858e-01  2.220e-01 -3.252 0.001147 ** 
    ## hodays            -2.720e-03  9.973e-01  9.448e-04 -2.879 0.003986 ** 
    ## hoattend          -6.306e-03  9.937e-01  2.565e-03 -2.458 0.013961 *  
    ## hosr730           -1.451e+00  2.343e-01  6.872e-01 -2.112 0.034707 *  
    ## blinkers1sttime   -3.135e-01  7.309e-01  1.789e-01 -1.753 0.079687 .  
    ## josr365            1.153e+00  3.166e+00  6.001e-01  1.921 0.054789 .  
    ## holastsprat        4.860e-03  1.005e+00  3.067e-03  1.585 0.113040    
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                   exp(coef) exp(-coef) lower .95 upper .95
    ## trsr               104.6103   0.009559   5.08491 2152.1135
    ## jowins365            1.0065   0.993556   1.00289    1.0101
    ## draweffect_median    0.9977   1.002299   0.96186    1.0349
    ## homean4sprat         1.0122   0.987936   1.00350    1.0210
    ## homeanearn365        1.0009   0.999142   1.00051    1.0012
    ## trmeanearn           1.0003   0.999701   1.00010    1.0005
    ## joam                 0.4858   2.058600   0.31435    0.7506
    ## hodays               0.9973   1.002724   0.99544    0.9991
    ## hoattend             0.9937   1.006325   0.98873    0.9987
    ## hosr730              0.2343   4.268478   0.06092    0.9009
    ## blinkers1sttime      0.7309   1.368259   0.51469    1.0378
    ## josr365              3.1661   0.315843   0.97662   10.2644
    ## holastsprat          1.0049   0.995152   0.99885    1.0109
    ## 
    ## Concordance= 0.684  (se = 0.014 )
    ## Likelihood ratio test= 196.7  on 13 df,   p=<2e-16
    ## Wald test            = 183.8  on 13 df,   p=<2e-16
    ## Score (logrank) test = 201.9  on 13 df,   p=<2e-16

The `selected_features` together with the `odds` will be used in the
next step to train our model.

# 5 Training and Testing the Model

## 5.1 Incorporating the Odds and training the Model

``` r
# final features: selected_features + odds
final_features <- c(selected_features, "odds")
final_features
```

    ##  [1] "trsr"              "jowins365"         "draweffect_median"
    ##  [4] "homean4sprat"      "homeanearn365"     "trmeanearn"       
    ##  [7] "joam"              "hodays"            "hoattend"         
    ## [10] "hosr730"           "blinkers1sttime"   "josr365"          
    ## [13] "holastsprat"       "odds"

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

    ## win ~ trsr + jowins365 + draweffect_median + homean4sprat + homeanearn365 + 
    ##     trmeanearn + joam + hodays + hoattend + hosr730 + blinkers1sttime + 
    ##     josr365 + holastsprat + odds + strata(dg_raceid)

``` r
# Fit the conditional logistic regression model
final_model <- clogit(final_model_formula, data = train_data, method = "exact")

# Print model summary
summary(final_model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5690L), win) ~ trsr + jowins365 + 
    ##     draweffect_median + homean4sprat + homeanearn365 + trmeanearn + 
    ##     joam + hodays + hoattend + hosr730 + blinkers1sttime + josr365 + 
    ##     holastsprat + odds + strata(dg_raceid), data = train_data, 
    ##     method = "exact")
    ## 
    ##   n= 5625, number of events= 524 
    ##    (65 observations deleted due to missingness)
    ## 
    ##                         coef  exp(coef)   se(coef)      z Pr(>|z|)    
    ## trsr               2.3205454 10.1812252  1.6325525  1.421   0.1552    
    ## jowins365          0.0014794  1.0014805  0.0019251  0.769   0.4422    
    ## draweffect_median -0.0012180  0.9987827  0.0190542 -0.064   0.9490    
    ## homean4sprat       0.0059515  1.0059692  0.0045107  1.319   0.1870    
    ## homeanearn365      0.0001358  1.0001358  0.0002060  0.659   0.5099    
    ## trmeanearn         0.0001440  1.0001440  0.0001064  1.352   0.1762    
    ## joam              -0.5629510  0.5695259  0.2244535 -2.508   0.0121 *  
    ## hodays            -0.0003929  0.9996072  0.0008411 -0.467   0.6404    
    ## hoattend          -0.0054027  0.9946119  0.0026642 -2.028   0.0426 *  
    ## hosr730           -1.0831422  0.3385301  0.7138791 -1.517   0.1292    
    ## blinkers1sttime   -0.2781344  0.7571951  0.1805649 -1.540   0.1235    
    ## josr365            0.8297855  2.2928270  0.6758248  1.228   0.2195    
    ## holastsprat        0.0027516  1.0027554  0.0031227  0.881   0.3782    
    ## odds              -0.0825744  0.9207429  0.0083933 -9.838   <2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                   exp(coef) exp(-coef) lower .95 upper .95
    ## trsr                10.1812    0.09822   0.41512  249.7073
    ## jowins365            1.0015    0.99852   0.99771    1.0053
    ## draweffect_median    0.9988    1.00122   0.96217    1.0368
    ## homean4sprat         1.0060    0.99407   0.99711    1.0149
    ## homeanearn365        1.0001    0.99986   0.99973    1.0005
    ## trmeanearn           1.0001    0.99986   0.99994    1.0004
    ## joam                 0.5695    1.75585   0.36682    0.8842
    ## hodays               0.9996    1.00039   0.99796    1.0013
    ## hoattend             0.9946    1.00542   0.98943    0.9998
    ## hosr730              0.3385    2.95395   0.08355    1.3717
    ## blinkers1sttime      0.7572    1.32066   0.53151    1.0787
    ## josr365              2.2928    0.43614   0.60969    8.6225
    ## holastsprat          1.0028    0.99725   0.99664    1.0089
    ## odds                 0.9207    1.08608   0.90572    0.9360
    ## 
    ## Concordance= 0.739  (se = 0.013 )
    ## Likelihood ratio test= 354.8  on 14 df,   p=<2e-16
    ## Wald test            = 208.4  on 14 df,   p=<2e-16
    ## Score (logrank) test = 245.6  on 14 df,   p=<2e-16

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

    ## Total number of bets: 912 
    ##  Total earnings: 91.2

Over the test period, our strategy identified 912 potentially profitable
bets. Assuming a uniform bet size of €1.00, the strategy would have
generated cumulative earnings of €91.2.

## 5.3 Outperforming the Market or just a few lucky Wins?

The cumulative earnings over the number of bets are plotted to assess
the overall profitability and the pattern of wins and losses over the
test period.

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

    ## Observed Earnings: 91.2 
    ##  Expected Loss (with 15% takeout): 136.8 
    ##  p-value: 0.0066

The bootstrap hypothesis test yields a p-value of 0.0066. This p-value
is less than the commonly used significance level of 0.05.

The low p-value (0.0066) indicates that the observed earnings of €91.2
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

The model could be improved by using k-fold cross-validation and an
information criterion (e.g., AIC) for variable selection. Additionally,
developing new and more sophisticated features or trying other methods
like random forests could enhance its predictive power.

``` r
AIC(final_model)
```

    ## [1] 2119.723

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
