Using Bill Benter’s Methods in German Horse Racing
================

``` r
library (data.table)
library(survival)
library(tidyverse)
library(zoo)
```

# 1 Horse Racing in Germany

## 1.1 Betting Market

Germany features two primary types of horse racing: Harness racing and
flat racing. Steeplechasing and hurdling have largely faded into
history. This notebook will concentrate on flat racing.

Betting plays a crucial role in German horse racing, as a portion of the
prize money is funded by the parimutuel betting operator’s profits.
Betting in Germany occurs through two primary channels: bookmakers
(fixed odds) and the totalizator (parimutuel). For this analysis, the
focus lies exclusively on parimutuel odds.

## 1.2 Takeout

In parimutuel betting, the track retains a commission known as takeout.
In Germany, the takeout for win and place markets is 15%. Our analysis
will concentrate solely on the win market.

# 2 Bill Benter’s Approach

Inspired by Bolton and Chapman’s (1986) paper, Bill Benter employed a
conditional logistic regression model to predict horse racing outcomes
in Hong Kong. His innovative approach incorporated the public’s
estimate, as reflected in betting odds, into his model. Following a
similar path, we’ll attempt to identify market inefficiencies within
German horse racing.

# 3 Data

The data used in this analysis has been acquired by web scraping. German
horse racing results since 2002 up until 2024 have been gathered. But
only the results since 2019 will be used in training and testing the
model because before 2019 the takeout rate was much higher than 15%.
Data before 2019 has however been used to construct the necessary
features. Similar features to those mentioned by Bolton and Chapman
(1986) have been engineered.

``` r
# Import data
races <- readRDS("../data/processed/engineered_features.Rds")
```

## 3.1 Feature Descriptions

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
  "hosr730", "hosr", "homean4sprat", "homeanearn365", "holastsprat",
  "hofirstrace", "hodays", "draweffect_median", "gag", "gagindicator", 
  "blinkers1sttime", "weight",
  
  # Jockey-related features
  "josr365", "jowins365", 
  
  # Trainer-related features
  "trsr",
  
  # Other features
  "odds"
)
```

## 3.2 Filtering and Preparing the Data

This section prepares the data for model training and prediction. Jump
races and stakes races are excluded as the focus is on flat races and
specifically “Ausgleich IV” handicap races. “Ausgleich IV” races are the
lowest class of racing in Germany and those races are run very
frequently with many observations per horse in a year. Additionally,
races before 2019 are removed due to a significantly different takeout
rate at that time. The data is further filtered to ensure data integrity
by removing races with missing odds, homean4sprat values, or stall
numbers. Lastly, races with dead heats are excluded and the data is
sorted by date and time.

``` r
# Finding races with dead heats
dead_heat_races <- races %>% 
  group_by(dg_raceid, position) %>%
  filter(position == 1) %>% 
  summarise(
    position1_count = n()
  ) %>%
  ungroup() %>% 
  filter(position1_count > 1) %>% 
  pull(dg_raceid) 
```

    ## `summarise()` has grouped output by 'dg_raceid'. You can override using the
    ## `.groups` argument.

``` r
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
        "dg_raceid", "date_time", "win", "dg_horseid", "horse", "hostall"
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

# 4 Training and Testing the Model

The dataset is split into a training set and a test set to evaluate the
model’s performance on unseen data. The training set includes races
before January 1, 2021, while the test set contains races from that date
onwards. This split allows us to assess how well the model generalizes
to new races and avoids overfitting to the training data.

``` r
# Create training dataset using races before 2021
train_data <- data %>% 
  filter(date_time < "2021-01-01 01:00:00")

test_data <- data %>% 
  filter(date_time > "2021-01-01 01:00:00") %>% 
  data.table()
```

## 4.1 Training the Model

A conditional logistic regression model (`clogit`) is employed to
predict the probability of a horse winning a race. This model is
wellsuited for analyzing data with multiple observations within groups
(horses within races) and allows us to account for the inherent
dependencies within each race. This approach is consistent with Bill
Benter’s strategy in horse race prediction. But in contrast to Benter’s
two-step approach to incorporate the public estimate (the odds), here a
one-step approach is utilized.

``` r
# Construct the model formula using the selected features
model_formula <- as.formula(
  paste(
    "win",
    paste(paste(features, collapse = " + "), "strata(dg_raceid)", sep = " + "),
    sep = " ~ "
  )
)
print(model_formula)
```

    ## win ~ hosr730 + hosr + homean4sprat + homeanearn365 + holastsprat + 
    ##     hofirstrace + hodays + draweffect_median + gag + gagindicator + 
    ##     blinkers1sttime + weight + josr365 + jowins365 + trsr + odds + 
    ##     strata(dg_raceid)

``` r
# Fit the conditional logistic regression model
model <- clogit(
  model_formula,
  data = train_data, method = "exact"
)

# Print model summary
summary(model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5690L), win) ~ hosr730 + hosr + homean4sprat + 
    ##     homeanearn365 + holastsprat + hofirstrace + hodays + draweffect_median + 
    ##     gag + gagindicator + blinkers1sttime + weight + josr365 + 
    ##     jowins365 + trsr + odds + strata(dg_raceid), data = train_data, 
    ##     method = "exact")
    ## 
    ##   n= 5620, number of events= 524 
    ##    (70 observations deleted due to missingness)
    ## 
    ##                         coef  exp(coef)   se(coef)       z Pr(>|z|)    
    ## hosr730           -2.590e+00  7.505e-02  1.583e+00  -1.636 0.101920    
    ## hosr               1.576e+00  4.837e+00  1.659e+00   0.950 0.342039    
    ## homean4sprat       5.266e-03  1.005e+00  4.757e-03   1.107 0.268363    
    ## homeanearn365      1.094e-04  1.000e+00  2.112e-04   0.518 0.604296    
    ## holastsprat        3.874e-03  1.004e+00  3.208e-03   1.208 0.227203    
    ## hofirstrace        3.487e-01  1.417e+00  5.389e-01   0.647 0.517542    
    ## hodays            -7.244e-05  9.999e-01  7.954e-04  -0.091 0.927436    
    ## draweffect_median -1.204e-03  9.988e-01  1.914e-02  -0.063 0.949827    
    ## gag               -1.217e-02  9.879e-01  3.147e-02  -0.387 0.698976    
    ## gagindicatorTRUE  -4.994e-02  9.513e-01  1.301e-01  -0.384 0.701136    
    ## blinkers1sttime   -3.147e-01  7.300e-01  1.802e-01  -1.747 0.080677 .  
    ## weight            -2.240e-03  9.978e-01  3.401e-02  -0.066 0.947479    
    ## josr365            6.925e-01  1.999e+00  6.773e-01   1.022 0.306568    
    ## jowins365          2.361e-03  1.002e+00  1.940e-03   1.217 0.223682    
    ## trsr               4.397e+00  8.122e+01  1.233e+00   3.565 0.000363 ***
    ## odds              -8.755e-02  9.162e-01  8.512e-03 -10.285  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                   exp(coef) exp(-coef) lower .95 upper .95
    ## hosr730             0.07505   13.32363  0.003371    1.6712
    ## hosr                4.83723    0.20673  0.187243  124.9648
    ## homean4sprat        1.00528    0.99475  0.995950    1.0147
    ## homeanearn365       1.00011    0.99989  0.999696    1.0005
    ## holastsprat         1.00388    0.99613  0.997589    1.0102
    ## hofirstrace         1.41727    0.70558  0.492897    4.0752
    ## hodays              0.99993    1.00007  0.998370    1.0015
    ## draweffect_median   0.99880    1.00121  0.962021    1.0370
    ## gag                 0.98791    1.01224  0.928820    1.0508
    ## gagindicatorTRUE    0.95129    1.05121  0.737136    1.2276
    ## blinkers1sttime     0.72999    1.36989  0.512798    1.0392
    ## weight              0.99776    1.00224  0.933418    1.0665
    ## josr365             1.99864    0.50034  0.529965    7.5374
    ## jowins365           1.00236    0.99764  0.998559    1.0062
    ## trsr               81.21828    0.01231  7.242346  910.8112
    ## odds                0.91617    1.09150  0.901015    0.9316
    ## 
    ## Concordance= 0.738  (se = 0.013 )
    ## Likelihood ratio test= 343.2  on 16 df,   p=<2e-16
    ## Wald test            = 194.2  on 16 df,   p=<2e-16
    ## Score (logrank) test = 219.6  on 16 df,   p=<2e-16

``` r
# Extract coefficients from the model summary
coeffs <- as.vector(summary(model)$coefficients[, 1])
coeffs
```

    ##  [1] -2.589539e+00  1.576343e+00  5.265532e-03  1.094228e-04  3.874319e-03
    ##  [6]  3.487297e-01 -7.244215e-05 -1.204398e-03 -1.216803e-02 -4.994064e-02
    ## [11] -3.147303e-01 -2.240451e-03  6.924687e-01  2.360865e-03  4.397140e+00
    ## [16] -8.754985e-02

## 4.2 Testing the Model

``` r
test_data <- data %>% 
  filter(
    date_time > "2021-01-01 01:00:00" 
  ) %>% 
  data.table()
```

Predictions

``` r
predictions <- test_data[, prediction := as.matrix(test_data[, ..features]) %*% coeffs]
```

    ## Warning: Both 'features' and '..features' exist in calling scope. Please remove
    ## the '..features' variable in calling scope for clarity.

``` r
predictions <- predictions %>% 
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
  mutate(
    earnings = ifelse(
      win == 1, odds - 1, -1
    )
  )

sum(predictions$earnings)
```

    ## [1] 19.9
