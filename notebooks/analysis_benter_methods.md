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
  "hofirstrace", "hodays", "draweffect_mean", "hono", "blinkers1sttime", "weight",
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
    ##     hofirstrace + hodays + draweffect_mean + hono + blinkers1sttime + 
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
    ##     homeanearn365 + holastsprat + hofirstrace + hodays + draweffect_mean + 
    ##     hono + blinkers1sttime + weight + josr365 + jowins365 + trsr + 
    ##     odds + strata(dg_raceid), data = train_data, method = "exact")
    ## 
    ##   n= 5639, number of events= 526 
    ##    (60 observations deleted due to missingness)
    ## 
    ##                       coef  exp(coef)   se(coef)       z Pr(>|z|)    
    ## hosr730         -2.490e+00  8.292e-02  1.518e+00  -1.640 0.100983    
    ## hosr             1.397e+00  4.043e+00  1.561e+00   0.895 0.370922    
    ## homean4sprat     5.184e-03  1.005e+00  4.736e-03   1.095 0.273627    
    ## homeanearn365    1.508e-04  1.000e+00  2.078e-04   0.726 0.467869    
    ## holastsprat      4.339e-03  1.004e+00  3.208e-03   1.353 0.176188    
    ## hofirstrace      3.738e-01  1.453e+00  5.379e-01   0.695 0.487029    
    ## hodays          -8.829e-05  9.999e-01  7.996e-04  -0.110 0.912080    
    ## draweffect_mean  3.952e-03  1.004e+00  1.604e-02   0.246 0.805400    
    ## hono             3.397e-02  1.035e+00  2.721e-02   1.248 0.211904    
    ## blinkers1sttime -3.168e-01  7.285e-01  1.802e-01  -1.758 0.078714 .  
    ## weight           1.440e-02  1.015e+00  2.790e-02   0.516 0.605691    
    ## josr365          6.573e-01  1.930e+00  6.756e-01   0.973 0.330584    
    ## jowins365        2.272e-03  1.002e+00  1.902e-03   1.195 0.232259    
    ## trsr             4.451e+00  8.572e+01  1.209e+00   3.681 0.000232 ***
    ## odds            -8.734e-02  9.164e-01  8.489e-03 -10.289  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##                 exp(coef) exp(-coef) lower .95 upper .95
    ## hosr730           0.08292   12.06013  0.004231    1.6251
    ## hosr              4.04336    0.24732  0.189522   86.2628
    ## homean4sprat      1.00520    0.99483  0.995911    1.0146
    ## homeanearn365     1.00015    0.99985  0.999744    1.0006
    ## holastsprat       1.00435    0.99567  0.998053    1.0107
    ## hofirstrace       1.45330    0.68809  0.506440    4.1704
    ## hodays            0.99991    1.00009  0.998346    1.0015
    ## draweffect_mean   1.00396    0.99606  0.972884    1.0360
    ## hono              1.03456    0.96660  0.980821    1.0912
    ## blinkers1sttime   0.72846    1.37275  0.511714    1.0370
    ## weight            1.01451    0.98570  0.960515    1.0715
    ## josr365           1.92960    0.51824  0.513333    7.2533
    ## jowins365         1.00227    0.99773  0.998545    1.0060
    ## trsr             85.72071    0.01167  8.013594  916.9468
    ## odds              0.91636    1.09127  0.901243    0.9317
    ## 
    ## Concordance= 0.74  (se = 0.013 )
    ## Likelihood ratio test= 345.2  on 15 df,   p=<2e-16
    ## Wald test            = 195.8  on 15 df,   p=<2e-16
    ## Score (logrank) test = 221.2  on 15 df,   p=<2e-16

``` r
coeffs <- as.vector(summary(model)$coefficients[, 1])
coeffs
```

    ##  [1] -2.489905e+00  1.397075e+00  5.184435e-03  1.508272e-04  4.339413e-03
    ##  [6]  3.738334e-01 -8.828933e-05  3.952303e-03  3.397179e-02 -3.168166e-01
    ## [11]  1.440484e-02  6.573119e-01  2.272273e-03  4.451094e+00 -8.734159e-02

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

    ## [1] -28.5
