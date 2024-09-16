R Notebook
================

``` r
library (data.table)
library(survival)
library(tidyverse)
```

    ## ── Attaching core tidyverse packages ──────────────────────── tidyverse 2.0.0 ──
    ## ✔ dplyr     1.1.4     ✔ readr     2.1.5
    ## ✔ forcats   1.0.0     ✔ stringr   1.5.1
    ## ✔ ggplot2   3.5.1     ✔ tibble    3.2.1
    ## ✔ lubridate 1.9.3     ✔ tidyr     1.3.1
    ## ✔ purrr     1.0.2     
    ## ── Conflicts ────────────────────────────────────────── tidyverse_conflicts() ──
    ## ✖ dplyr::between()     masks data.table::between()
    ## ✖ dplyr::filter()      masks stats::filter()
    ## ✖ dplyr::first()       masks data.table::first()
    ## ✖ lubridate::hour()    masks data.table::hour()
    ## ✖ lubridate::isoweek() masks data.table::isoweek()
    ## ✖ dplyr::lag()         masks stats::lag()
    ## ✖ dplyr::last()        masks data.table::last()
    ## ✖ lubridate::mday()    masks data.table::mday()
    ## ✖ lubridate::minute()  masks data.table::minute()
    ## ✖ lubridate::month()   masks data.table::month()
    ## ✖ lubridate::quarter() masks data.table::quarter()
    ## ✖ lubridate::second()  masks data.table::second()
    ## ✖ purrr::transpose()   masks data.table::transpose()
    ## ✖ lubridate::wday()    masks data.table::wday()
    ## ✖ lubridate::week()    masks data.table::week()
    ## ✖ lubridate::yday()    masks data.table::yday()
    ## ✖ lubridate::year()    masks data.table::year()
    ## ℹ Use the conflicted package (<http://conflicted.r-lib.org/>) to force all conflicts to become errors

``` r
library(zoo)
```

    ## 
    ## Attaching package: 'zoo'
    ## 
    ## The following objects are masked from 'package:data.table':
    ## 
    ##     yearmon, yearqtr
    ## 
    ## The following objects are masked from 'package:base':
    ## 
    ##     as.Date, as.Date.numeric

``` r
# set working directory to directory in which script is stored
script_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_path)
```

``` r
getwd()
```

    ## [1] "C:/Users/chris/Documents/GitHub/german-horse-racing/notebooks"

Contents - Horse Racing in Germany: Betting and Takeout - Benter’s
Model - Data - Features - Train Data - Test Data

# 1 Horse Racing in Germany

## 1.1 Betting Market

Germany features two primary types of horse racing: Harness racing and
flat racing. Steeplechasing and hurdling have largely faded into
history. This notebook will concentrate on flat racing. Betting plays a
crucial role in German racing, as a portion of the prize money is funded
by the parimutuel betting operator’s profits.

Betting in Germany occurs through two primary channels: bookmakers
(fixed odds) and the totalizator (parimutuel). For this analysis, we’ll
focus exclusively on parimutuel odds.

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

The data used in our analysis has been acquired by web scraping. We have
gathered german horse racing results since 2002 up until now. But only
the results since 2019 will be used in training and testing the model
because before 2019 the takeout rate was much higher than 15%. Data
before 2019 has however been used to construct the necessary features.
Similar features to those mentioned by Bolton and Chapman (1986) have
been engineered.

``` r
data <- readRDS("../data/processed/cleaned_german_racing_data.Rds")
```

LIFE%WIN = hosr730, hosr AVESPRAT = homean4sprat W/RACE = homeanearn365
LSPEDRAT = holastsprat JOCK%WIN = josr365 JOCK#WIN = jowins365 WEIGHT =
weight POSTPOS = hostall

## 3.1 Data Import

``` r
races <- readRDS("../data/processed/engineered_features.Rds")
```

## 3.2 Filtering the Data

Some jump races are also part of the dataset. But we only use flat races
run on turf. We won’t analyse stakes races. Instead we concentrate on
Handicap races and in particular “Ausgleich IV” races which are lowest
class of racing Germany. But those race are run very frequently with
many observations per horse in a year.

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
    dg_raceid, win, date_time, hosr730, hosr, homean4sprat, homeanearn365, 
    holastsprat, hoattend, josr365, jowins365, weight, hostall, hono, odds, 
    dg_raceid, dg_horseid, horse, hofirstrace, hodays, trsr 
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

LIFE%WIN = hosr730, hosr AVESPRAT = homean4sprat W/RACE = homeanearn365
LSPEDRAT = holastsprat JOCK%WIN = josr365 JOCK#WIN = jowins365 WEIGHT =
weight POSTPOS = hostall

# Train Data

``` r
train_data <- data %>% 
  filter(date_time < "2021-01-01 01:00:00")
```

Model

- hosr + homean4sprat + homeanearn365 + holastsprat + josr365 +
  jowins365 + weight + hostall + hono + hofirstrace

``` r
features <- c(
  "hosr730", "hosr", "homean4sprat", "homeanearn365", "holastsprat", "josr365", 
  "jowins365", "weight", "hostall", "hono", "hofirstrace", "hodays", "trsr", 
  "odds"
)

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
    ##     josr365 + jowins365 + weight + hostall + hono + hofirstrace + 
    ##     hodays + trsr + odds + strata(dg_raceid)

``` r
model <- clogit(
  model_formula,
  data = train_data, method = "exact"
)
summary(model)
```

    ## Call:
    ## coxph(formula = Surv(rep(1, 5699L), win) ~ hosr730 + hosr + homean4sprat + 
    ##     homeanearn365 + holastsprat + josr365 + jowins365 + weight + 
    ##     hostall + hono + hofirstrace + hodays + trsr + odds + strata(dg_raceid), 
    ##     data = train_data, method = "exact")
    ## 
    ##   n= 5699, number of events= 532 
    ## 
    ##                     coef  exp(coef)   se(coef)       z Pr(>|z|)    
    ## hosr730       -2.301e+00  1.001e-01  1.495e+00  -1.539 0.123746    
    ## hosr           1.359e+00  3.894e+00  1.549e+00   0.878 0.380111    
    ## homean4sprat   4.211e-03  1.004e+00  4.682e-03   0.899 0.368503    
    ## homeanearn365  1.377e-04  1.000e+00  2.045e-04   0.674 0.500580    
    ## holastsprat    4.679e-03  1.005e+00  3.146e-03   1.487 0.136908    
    ## josr365        6.623e-01  1.939e+00  6.741e-01   0.982 0.325871    
    ## jowins365      2.266e-03  1.002e+00  1.898e-03   1.194 0.232394    
    ## weight         1.800e-02  1.018e+00  2.779e-02   0.648 0.517044    
    ## hostall        1.249e-03  1.001e+00  1.336e-02   0.093 0.925510    
    ## hono           3.569e-02  1.036e+00  2.715e-02   1.314 0.188686    
    ## hofirstrace    3.705e-01  1.448e+00  5.362e-01   0.691 0.489666    
    ## hodays         4.654e-05  1.000e+00  7.533e-04   0.062 0.950739    
    ## trsr           4.237e+00  6.923e+01  1.199e+00   3.533 0.000411 ***
    ## odds          -8.780e-02  9.159e-01  8.450e-03 -10.390  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##               exp(coef) exp(-coef) lower .95 upper .95
    ## hosr730          0.1001    9.98656  0.005346    1.8757
    ## hosr             3.8942    0.25679  0.187051   81.0741
    ## homean4sprat     1.0042    0.99580  0.995046    1.0135
    ## homeanearn365    1.0001    0.99986  0.999737    1.0005
    ## holastsprat      1.0047    0.99533  0.998515    1.0109
    ## josr365          1.9392    0.51567  0.517403    7.2681
    ## jowins365        1.0023    0.99774  0.998548    1.0060
    ## weight           1.0182    0.98216  0.964201    1.0752
    ## hostall          1.0013    0.99875  0.975364    1.0278
    ## hono             1.0363    0.96494  0.982628    1.0930
    ## hofirstrace      1.4484    0.69042  0.506332    4.1433
    ## hodays           1.0000    0.99995  0.998571    1.0015
    ## trsr            69.2341    0.01444  6.597741  726.5154
    ## odds             0.9159    1.09177  0.900897    0.9312
    ## 
    ## Concordance= 0.741  (se = 0.013 )
    ## Likelihood ratio test= 343.8  on 14 df,   p=<2e-16
    ## Wald test            = 193.4  on 14 df,   p=<2e-16
    ## Score (logrank) test = 218.5  on 14 df,   p=<2e-16

``` r
coeffs <- as.vector(summary(model)$coefficients[, 1])
coeffs
```

    ##  [1] -2.301240e+00  1.359493e+00  4.210846e-03  1.377145e-04  4.679069e-03
    ##  [6]  6.622799e-01  2.266201e-03  1.800236e-02  1.249498e-03  3.568654e-02
    ## [11]  3.704604e-01  4.653997e-05  4.237494e+00 -8.780169e-02

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
    expected_value == max(expected_value),
    odds < 10
  ) %>% 
  ungroup() %>% 
  mutate(
    earnings = ifelse(
      win == 1, odds - 1, -1
    )
  )

sum(predictions$earnings)
```

    ## [1] -42.6
