# Loading packages
library(data.table)
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
    ),
    # hodays: days since last race
    hodays = as.numeric(
      difftime(date_time, lag(date_time, default = NA), units = "days")
    ),
    hodays_turf = difftime(
      date_time,
      lag(
        na.locf(if_else(surface == "Turf", date_time, NA), na.rm = FALSE)
      ),
      units = "days"
    ),
    hodays_dirt = difftime(
      date_time,
      lag(
        na.locf(if_else(surface == "Dirt", date_time, NA), na.rm = FALSE)
      ),
      units = "days"
    ),
    # first time blinkers
    blinkers1sttime = as.integer(cumsum(blinkers == 1) == 1)
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
  mutate(
    trattend1 = row_number() - 1,
    trwins1 = lag(cumsum(win), default = 0)
  ) %>% 
  ungroup()

races <- races %>% 
  group_by(trainer, dg_raceid) %>% 
  mutate(
    trattend = min(trattend1),
    trwins = min(trwins1),
    trsr = ifelse(trattend == 0, 0, trwins / trattend)
  ) %>% 
  select(-c(trattend1, trwins1)) %>% 
  ungroup()



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



##---------------------------- DRAW EFFECT -----------------------------------##

# In german racing stall 1 isn't always stall 1. 
# Instead it is the most inner stall
# So the draw effect will be calculated as the disadvantages of the outer stalls
# in comparison to the innermost stall.
ausgleich4 <- races %>% 
  filter(
    race_class_old == "Ausgleich IV", surface == "Turf", !is.na(hostall)
  ) %>%
  group_by(dg_raceid) %>% 
  mutate(
    # there are cases of non runners in stall 1. Innermost stall will be stall 1
    hodraw = min_rank(hostall)
  )
distance_stall1 <- ausgleich4 %>% 
  filter(hostall == 1) %>% 
  select(dg_raceid, dist_btn_cum) %>% 
  rename(diststall1winner = dist_btn_cum)
ausgleich4 <- left_join(ausgleich4, distance_stall1, by = c("dg_raceid")) %>% 
  mutate(diststall1 = dist_btn_cum - diststall1winner) %>% 
  select(- diststall1winner)

# Calculate draweffect
draweffect <- ausgleich4 %>% 
  filter(year(date_time) < 2019) %>% 
  group_by(dg_course, race_distance, hodraw) %>% 
  summarise(
    count = n(),
    draweffect_mean = mean(diststall1, na.rm = TRUE),
    draweffect_median = median(diststall1, na.rm = TRUE)
  ) %>% 
  select(- count)
races <- races %>% 
  group_by(dg_raceid) %>% 
  mutate(hodraw = min_rank(hostall)) %>% 
  ungroup() %>% 
  left_join(
    draweffect, by = c("dg_course", "race_distance", "hodraw")
  ) %>% 
  ungroup()


# GAG Indicator: Hcp lower than before last win?
races <- races %>% 
  arrange(date_time) %>% 
  group_by(dg_horseid) %>% 
  mutate(
    gagindicator = gag < lag(
      replace_na(
        na.locf(
          ifelse(position == 1 & surface == "Turf", gag, NA), na.rm = FALSE
        ), 
        0
      ),
      default = 0
    ),
    gag_lastwin = lag(
      replace_na(
        na.locf(
          ifelse(position == 1 & surface == "Turf", gag, NA), na.rm = FALSE
        ), 
        0
      ),
      default = 0
    )
  ) %>% 
  ungroup()
  


saveRDS(races, "../data/processed/engineered_features.Rds")
