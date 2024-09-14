# Loading packages
library(runner)
library(tidyverse)
library(zoo)

# set working directory to directory in which script is stored
script_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_path)

# import data
races <- readRDS("../data/processed/cleaned_german_racing_data.Rds")


# course records (2002-2018)
races <- races %>% 
  group_by(dg_course, race_distance, surface) %>% 
  mutate(
    course_record = min(race_time_secs, na.rm = TRUE)
  ) %>% 
  ungroup()


# Horse features
races <- races %>% 
  arrange(date_time) %>% 
  group_by(dg_horseid) %>% 
  mutate(
    # dependent variable win
    win = ifelse(is.na(position), 0, ifelse(position == 1, 1, 0)),
    hoattend = row_number() - 1,
    hoattend_turf = lag(cumsum(surface == "Turf"), default = 0),
    hoattend_dirt = lag(cumsum(surface == "Sand"), default = 0),
    hoattend365 = lag(
      sum_run(x = !is.na(dg_horseid), k = 365, idx = as.Date(date_time)),
      default = 0
    ),
    hoattend730 = lag(
      sum_run(x = !is.na(dg_horseid), k = 730, idx = as.Date(date_time)),
      default = 0
    ),
    hofirstrace = ifelse(hoattend == 0, 1, 0),
    howins = lag(cumsum(win), default = 0),
    howins730 = lag(
      sum_run(x = win, k = 730, idx = as.Date(date_time)),
      default = 0
    ),
    howins_turf = lag(cumsum(ifelse(surface == "Turf", win, 0)), default = 0),
    howins_dirt = lag(cumsum(ifelse(surface == "Sand", win, 0)), default = 0),
    hosr = ifelse(hoattend == 0, 0, howins / hoattend),
    hosr_turf = ifelse(hoattend_turf == 0, 0, howins_turf / hoattend_turf), 
    hosr_dirt = ifelse(hoattend_dirt == 0, 0, howins_dirt / hoattend_dirt),
    hosr730 = ifelse(hoattend730 == 0, 0, howins730 / hoattend730),
    hoearnings = lag(cumsum(earnings), default = 0),
    hoearnings_turf = lag(
      cumsum(ifelse(surface == "Turf", earnings, 0)), default = 0
    ),
    hoearnings_dirt = lag(
      cumsum(ifelse(surface == "Dirt", earnings, 0)), default = 0
    ),
    hoearnings365 = lag(
      sum_run(x = earnings, k = 365, idx = as.Date(date_time))
    ),
    homeanearn = ifelse(hoattend == 0, 0, hoearnings / hoattend),
    homeanearn_turf = ifelse(
      hoattend_turf == 0, 0, hoearnings_turf / hoattend_turf
    ),
    homeanearn_dirt = ifelse(
      hoattend_dirt == 0, 0, hoearnings_dirt / hoattend_dirt
    ),
    homeanearn365 = ifelse(hoattend365 == 0, 0, hoearnings365 / hoattend365),
    hosprat = 100 + (course_record - hotime) * 5,
    hosprat = ifelse(hosprat < 0, 0, hosprat),
    holastsprat = lag(hosprat, default = 0),
    homean4sprat = lag(
      rollapplyr(hosprat, 4, mean, na.rm = TRUE, partial = TRUE), default = 0
    )  
  ) %>% 
  ungroup()

# Jockey features
races <- races %>% 
  arrange(date_time) %>% 
  group_by(jockey) %>% 
  mutate(
    joattend = row_number() - 1,
    joattend_turf = lag(cumsum(surface == "Turf"), default = 0),
    joattend_dirt = lag(cumsum(surface == "Sand"), default = 0),
    joattend365 = lag(
      sum_run(x = !is.na(jockey), k = 365, idx = as.Date(date_time)),
      default = 0
    ),
    jowins = lag(cumsum(win), default = 0),
    jowins_turf = lag(cumsum(ifelse(surface == "Turf", win, 0)), default = 0),
    jowins_dirt = lag(cumsum(ifelse(surface == "Sand", win, 0)), default = 0),
    jowins365 = lag(
      sum_run(x = win, k = 365, idx = as.Date(date_time)),
      default = 0
    ),
    josr = jowins / joattend,
    josr_turf = jowins_turf / joattend_turf, 
    josr_dirt = jowins_dirt / joattend_dirt,
    josr365 = ifelse(joattend365 == 0, 0, jowins365 / joattend365),
    joearnings = lag(cumsum(earnings), default = 0),
    joearnings_turf = lag(
      cumsum(ifelse(surface == "Turf", earnings, 0)), default = 0
    ),
    joearnings_dirt = lag(
      cumsum(ifelse(surface == "Dirt", earnings, 0)), default = 0
    ),
    jomeanearn = joearnings / joattend,
    jomeanearn_turf = joearnings_turf / joattend_turf,
    jomeanearn_dirt = joearnings_dirt / joattend_dirt
  ) %>% 
  ungroup()

# Trainer features
races <- races %>% 
  group_by(trainer) %>% 
  



# Market features
races <- races %>% 
  group_by(dg_raceid) %>% 
  mutate(
    reciprocal_odds = 1 / odds,
    sum_rec_odds = sum(reciprocal_odds),
    # public estimate
    pub_est = reciprocal_odds / sum_rec_odds
  ) %>% 
  ungroup()


saveRDS(races, "../data/processed/engineered_features.Rds")
