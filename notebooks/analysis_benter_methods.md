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
- **`homeanearn365`**: Horse’s mean earnings in the last 365 days
- **`holastsprat`**: Horse’s last speed rating
- **`hofirstrace`**: Indicator if it’s the horse’s first race
- **`hodays`**: Number of days since the horse’s last race
- **`hostall`**: Horse’s stall number
- **`hono`**: Horse’s number in the race card
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
features <- c(
  "hosr730", "hosr", "homean4sprat", "homeanearn365", "holastsprat", 
  "hofirstrace", "hodays", "hostall", "hono", "blinkers1sttime", "weight",
  "josr365", "jowins365", 
  "trsr", 
  "odds"
)
```

## 3.2 Filtering the Data

Some jump races are also part of the dataset. But only flat races run on
turf will be used. Stakes races won’t be analysed. The focus will lie
instead on Handicap races and in particular “Ausgleich IV” races which
are the lowest class of racing Germany. Those races are run very
frequently with many observations per horse in a year.

DEAD HEATS!!

``` r
data <- races %>% 
  filter(
    race_class_old == "Ausgleich IV",
    date_time > "2019-01-01 01:00:00",
    race_type == "flat",
    surface == "Turf"
  ) %>% 
  select(
    all_of(
      c(
        features,
        "dg_raceid", "date_time", "win", "dg_horseid", "horse"
      )
    )
  ) %>% 
  filter(
    !is.na(odds)
  ) %>% 
  mutate(
    hodays = ifelse(hofirstrace == 1, 0, hodays)
  )

# homean4sprat missing (different reasons) exclude those races
races_missing_data <- data %>% 
  filter(is.na(homean4sprat)) %>% 
  pull(dg_raceid)

data <- data %>% 
  filter(! dg_raceid %in% races_missing_data)

# find races where stall numbers are missing
races_missing_stall <- data %>%  
  filter(is.na(hostall)) %>% 
  pull(dg_raceid)
data <- data %>% 
  filter(!dg_raceid %in% races_missing_stall)

data <- data %>% 
  arrange(date_time) %>% 
  mutate(holastsprat = na.locf(holastsprat))
```

# Train Data

``` r
train_data <- data %>% 
  filter(date_time < "2021-01-01 01:00:00")
```

Model

- hosr + homean4sprat + homeanearn365 + holastsprat + josr365 +
  jowins365 + weight + hostall + hono + hofirstrace

``` r
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
    ##     hofirstrace + hodays + hostall + hono + blinkers1sttime + 
    ##     weight + josr365 + jowins365 + trsr + odds + strata(dg_raceid)

``` r
model <- clogit(
  model_formula,
  data = train_data, method = "exact"
)
summary(model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5699L), win) ~ hosr730 + hosr + homean4sprat + 
    ##     homeanearn365 + holastsprat + hofirstrace + hodays + hostall + 
    ##     hono + blinkers1sttime + weight + josr365 + jowins365 + trsr + 
    ##     odds + strata(dg_raceid), data = train_data, method = "exact")
    ## 
    ##   n= 5699, number of events= 532 
    ## 
    ##                       coef  exp(coef)   se(coef)       z Pr(>|z|)    
    ## hosr730         -2.424e+00  8.860e-02  1.503e+00  -1.612   0.1069    
    ## hosr             1.407e+00  4.084e+00  1.550e+00   0.908   0.3639    
    ## homean4sprat     4.428e-03  1.004e+00  4.689e-03   0.944   0.3449    
    ## homeanearn365    1.512e-04  1.000e+00  2.056e-04   0.736   0.4619    
    ## holastsprat      4.667e-03  1.005e+00  3.148e-03   1.482   0.1383    
    ## hofirstrace      3.764e-01  1.457e+00  5.368e-01   0.701   0.4832    
    ## hodays           4.888e-05  1.000e+00  7.569e-04   0.065   0.9485    
    ## hostall          2.002e-03  1.002e+00  1.341e-02   0.149   0.8813    
    ## hono             3.538e-02  1.036e+00  2.714e-02   1.304   0.1923    
    ## blinkers1sttime -3.032e-01  7.384e-01  1.781e-01  -1.702   0.0887 .  
    ## weight           1.795e-02  1.018e+00  2.777e-02   0.646   0.5181    
    ## josr365          6.426e-01  1.901e+00  6.724e-01   0.956   0.3392    
    ## jowins365        2.280e-03  1.002e+00  1.894e-03   1.204   0.2288    
    ## trsr             4.341e+00  7.675e+01  1.201e+00   3.615   0.0003 ***
    ## odds            -8.752e-02  9.162e-01  8.444e-03 -10.366   <2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                 exp(coef) exp(-coef) lower .95 upper .95
    ## hosr730            0.0886   11.28628  0.004654    1.6867
    ## hosr               4.0841    0.24485  0.195847   85.1663
    ## homean4sprat       1.0044    0.99558  0.995250    1.0137
    ## homeanearn365      1.0002    0.99985  0.999748    1.0006
    ## holastsprat        1.0047    0.99534  0.998497    1.0109
    ## hofirstrace        1.4570    0.68633  0.508772    4.1726
    ## hodays             1.0000    0.99995  0.998566    1.0015
    ## hostall            1.0020    0.99800  0.976011    1.0287
    ## hono               1.0360    0.96524  0.982349    1.0926
    ## blinkers1sttime    0.7384    1.35421  0.520830    1.0470
    ## weight             1.0181    0.98221  0.964175    1.0751
    ## josr365            1.9015    0.52590  0.509061    7.1026
    ## jowins365          1.0023    0.99772  0.998568    1.0060
    ## trsr              76.7493    0.01303  7.296324  807.3177
    ## odds               0.9162    1.09147  0.901159    0.9315
    ## 
    ## Concordance= 0.74  (se = 0.013 )
    ## Likelihood ratio test= 346.8  on 15 df,   p=<2e-16
    ## Wald test            = 196.5  on 15 df,   p=<2e-16
    ## Score (logrank) test = 221.8  on 15 df,   p=<2e-16

``` r
coeffs <- as.vector(summary(model)$coefficients[, 1])
coeffs
```

    ##  [1] -2.423588e+00  1.407093e+00  4.428323e-03  1.512430e-04  4.666526e-03
    ##  [6]  3.763894e-01  4.887573e-05  2.001574e-03  3.537706e-02 -3.032204e-01
    ## [11]  1.795020e-02  6.426390e-01  2.280086e-03  4.340544e+00 -8.752413e-02

# Test Data

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
  ) %>% 
  ungroup() %>% 
  mutate(
    earnings = ifelse(
      win == 1, odds - 1, -1
    )
  )

sum(predictions$earnings)
```

    ## [1] -43.2
