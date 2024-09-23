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
  "hofirstrace", "hodays", "draweffect_median", "gag", "blinkers1sttime", "weight",
  "josr365", "jowins365", "gagindicator", 
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
  ) 
```

Filter out races with dead heats:

``` r
dead_heat_races <- data %>% 
  group_by(dg_raceid, position) %>%
  filter(position == 1) %>% 
  summarise(
    position1_count = n()
  ) %>% 
  filter(position1_count > 1) %>% 
  pull(dg_raceid)
```

    ## `summarise()` has grouped output by 'dg_raceid'. You can override using the
    ## `.groups` argument.

``` r
data <- data %>% 
  filter(!dg_raceid %in% dead_heat_races)
```

Selecting the needed columns:

``` r
data <- data %>% 
  select(
    all_of(
      c(
        features,
        "dg_raceid", "date_time", "win", "dg_horseid", "horse", "hostall"
      )
    )
  ) %>% 
  filter(
    !is.na(odds)
  ) %>% 
  mutate(
    hodays = ifelse(hofirstrace == 1, 0, hodays)
  )
```

``` r
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
    ##     hofirstrace + hodays + draweffect_median + gag + blinkers1sttime + 
    ##     weight + josr365 + jowins365 + gagindicator + trsr + odds + 
    ##     strata(dg_raceid)

``` r
model <- clogit(
  model_formula,
  data = train_data, method = "exact"
)
summary(model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5690L), win) ~ hosr730 + hosr + homean4sprat + 
    ##     homeanearn365 + holastsprat + hofirstrace + hodays + draweffect_median + 
    ##     gag + blinkers1sttime + weight + josr365 + jowins365 + gagindicator + 
    ##     trsr + odds + strata(dg_raceid), data = train_data, method = "exact")
    ## 
    ##   n= 5630, number of events= 524 
    ##    (60 observations deleted due to missingness)
    ## 
    ##                         coef  exp(coef)   se(coef)       z Pr(>|z|)    
    ## hosr730           -2.596e+00  7.454e-02  1.582e+00  -1.641 0.100718    
    ## hosr               1.583e+00  4.872e+00  1.658e+00   0.955 0.339523    
    ## homean4sprat       5.090e-03  1.005e+00  4.741e-03   1.074 0.282981    
    ## homeanearn365      1.133e-04  1.000e+00  2.109e-04   0.537 0.591289    
    ## holastsprat        4.116e-03  1.004e+00  3.206e-03   1.284 0.199200    
    ## hofirstrace        3.558e-01  1.427e+00  5.390e-01   0.660 0.509204    
    ## hodays            -8.482e-05  9.999e-01  7.960e-04  -0.107 0.915139    
    ## draweffect_median -1.193e-03  9.988e-01  1.915e-02  -0.062 0.950309    
    ## gag               -1.276e-02  9.873e-01  3.147e-02  -0.405 0.685192    
    ## blinkers1sttime   -3.155e-01  7.294e-01  1.802e-01  -1.751 0.079914 .  
    ## weight            -2.134e-03  9.979e-01  3.403e-02  -0.063 0.950007    
    ## josr365            6.969e-01  2.008e+00  6.772e-01   1.029 0.303427    
    ## jowins365          2.390e-03  1.002e+00  1.940e-03   1.232 0.217918    
    ## gagindicatorTRUE  -4.752e-02  9.536e-01  1.301e-01  -0.365 0.714850    
    ## trsr               4.409e+00  8.220e+01  1.233e+00   3.577 0.000348 ***
    ## odds              -8.753e-02  9.162e-01  8.507e-03 -10.289  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                   exp(coef) exp(-coef) lower .95 upper .95
    ## hosr730             0.07454   13.41561  0.003357    1.6552
    ## hosr                4.87168    0.20527  0.189018  125.5609
    ## homean4sprat        1.00510    0.99492  0.995807    1.0145
    ## homeanearn365       1.00011    0.99989  0.999700    1.0005
    ## holastsprat         1.00412    0.99589  0.997835    1.0105
    ## hofirstrace         1.42727    0.70064  0.496287    4.1047
    ## hodays              0.99992    1.00008  0.998356    1.0015
    ## draweffect_median   0.99881    1.00119  0.962012    1.0370
    ## gag                 0.98732    1.01284  0.928257    1.0501
    ## blinkers1sttime     0.72939    1.37100  0.512374    1.0383
    ## weight              0.99787    1.00214  0.933482    1.0667
    ## josr365             2.00753    0.49812  0.532397    7.5699
    ## jowins365           1.00239    0.99761  0.998589    1.0062
    ## gagindicatorTRUE    0.95359    1.04867  0.739015    1.2305
    ## trsr               82.20434    0.01216  7.337936  920.9065
    ## odds                0.91619    1.09147  0.901045    0.9316
    ## 
    ## Concordance= 0.739  (se = 0.013 )
    ## Likelihood ratio test= 344.5  on 16 df,   p=<2e-16
    ## Wald test            = 194.9  on 16 df,   p=<2e-16
    ## Score (logrank) test = 220.7  on 16 df,   p=<2e-16

``` r
coeffs <- as.vector(summary(model)$coefficients[, 1])
coeffs
```

    ##  [1] -2.596419e+00  1.583439e+00  5.090279e-03  1.132638e-04  4.115498e-03
    ##  [6]  3.557626e-01 -8.481837e-05 -1.193456e-03 -1.275907e-02 -3.155402e-01
    ## [11] -2.133678e-03  6.969062e-01  2.390023e-03 -4.751851e-02  4.409208e+00
    ## [16] -8.752676e-02

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
  )  %>% 
  ungroup() %>% 
  mutate(
    earnings = ifelse(
      win == 1, odds - 1, -1
    )
  )

sum(predictions$earnings)
```

    ## [1] 28
