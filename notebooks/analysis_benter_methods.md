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
    dg_raceid, dg_horseid, horse, hofirstrace, hodays 
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
  "jowins365", "weight", "hostall", "hono", "hofirstrace", "hodays", "odds"
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
    ##     hodays + odds + strata(dg_raceid)

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
    ##     hostall + hono + hofirstrace + hodays + odds + strata(dg_raceid), 
    ##     data = train_data, method = "exact")
    ## 
    ##   n= 5699, number of events= 532 
    ## 
    ##                     coef  exp(coef)   se(coef)       z Pr(>|z|)    
    ## hosr730       -1.812e+00  1.634e-01  1.492e+00  -1.214   0.2246    
    ## hosr           9.264e-01  2.525e+00  1.547e+00   0.599   0.5493    
    ## homean4sprat   3.749e-03  1.004e+00  4.655e-03   0.806   0.4205    
    ## homeanearn365  3.879e-05  1.000e+00  2.063e-04   0.188   0.8509    
    ## holastsprat    4.754e-03  1.005e+00  3.128e-03   1.520   0.1286    
    ## josr365        1.109e+00  3.032e+00  5.973e-01   1.857   0.0633 .  
    ## jowins365      9.558e-04  1.001e+00  2.387e-03   0.400   0.6889    
    ## weight         2.545e-02  1.026e+00  2.772e-02   0.918   0.3586    
    ## hostall        1.912e-03  1.002e+00  1.335e-02   0.143   0.8861    
    ## hono           3.498e-02  1.036e+00  2.703e-02   1.294   0.1956    
    ## hofirstrace    4.126e-01  1.511e+00  5.309e-01   0.777   0.4371    
    ## hodays         1.134e-04  1.000e+00  7.102e-04   0.160   0.8731    
    ## odds          -9.414e-02  9.102e-01  8.435e-03 -11.161   <2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ##               exp(coef) exp(-coef) lower .95 upper .95
    ## hosr730          0.1634     6.1209  0.008777    3.0410
    ## hosr             2.5255     0.3960  0.121777   52.3753
    ## homean4sprat     1.0038     0.9963  0.994641    1.0130
    ## homeanearn365    1.0000     1.0000  0.999635    1.0004
    ## holastsprat      1.0048     0.9953  0.998624    1.0109
    ## josr365          3.0322     0.3298  0.940518    9.7755
    ## jowins365        1.0010     0.9990  0.996284    1.0057
    ## weight           1.0258     0.9749  0.971528    1.0831
    ## hostall          1.0019     0.9981  0.976033    1.0285
    ## hono             1.0356     0.9656  0.982159    1.0919
    ## hofirstrace      1.5107     0.6620  0.533662    4.2764
    ## hodays           1.0001     0.9999  0.998722    1.0015
    ## odds             0.9102     1.0987  0.895233    0.9253
    ## 
    ## Concordance= 0.736  (se = 0.013 )
    ## Likelihood ratio test= 331.4  on 13 df,   p=<2e-16
    ## Wald test            = 177.1  on 13 df,   p=<2e-16
    ## Score (logrank) test = 192  on 13 df,   p=<2e-16

``` r
coeffs <- as.vector(summary(model)$coefficients[, 1])
coeffs
```

    ##  [1] -1.811705e+00  9.264366e-01  3.749374e-03  3.878921e-05  4.754198e-03
    ##  [6]  1.109275e+00  9.557807e-04  2.545456e-02  1.912220e-03  3.498165e-02
    ## [11]  4.125584e-01  1.134137e-04 -9.413940e-02

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

    ## [1] -64.3
