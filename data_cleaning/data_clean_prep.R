library(lubridate)
library(stringi)
library(tidyverse)


##----------- Import Data ----------------------------------------------------##

# set working directory to directory in which script is stored
script_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_path)

races <- readRDS("../data/intermediate/im_german_racing_data.RData")


# change column data types
races$date_time <- ymd_hms(races$date_time)


##----------------------------------------------------------------------------##
##----------- Format, clean, and add columns ---------------------------------##
##----------------------------------------------------------------------------##


##----------- Hurdle races, steeplechase and flat racing ---------------------##

# Variable race_type
races$race_type <- ifelse(
  grepl("Huerdenrennen", races$race_category),
  "hurdle",
  ifelse(
    grepl("Jagdrennen", races$race_category), "chase","flat"
  )
)



##----------- fehlerhafte Pferdenamen verbessern -----------------------------##

horse_name_errors <- races %>% 
  group_by(dg_horseid) %>% 
  summarize(num_names = n_distinct(horse)) 



races$horse <- ifelse(races$dg_horseid == 1265681, "Iron on Fire", races$horse)
races$horse <- ifelse(races$dg_horseid == 1287464, "Simeon", races$horse)
races$horse <- ifelse(races$dg_horseid == 1685149, "Tappalugo", races$horse)
races$horse <- ifelse(races$dg_horseid == 2424178, "Icys Son", races$horse)
races$horse <- ifelse(races$dg_horseid == 6482882, "Irean", races$horse)
races$horse <- ifelse(races$dg_horseid == 7984876, "Catera", races$horse)



##--------------------- Going and Surface ------------------------------------##
##----------- Adding missing and replacing wrong going values ----------------##

# import lookup table
going_lookup_tbl <- read.csv("../data/raw/going_replacements.csv")
going_lookup_tbl$date_time <- ymd_hms(going_lookup_tbl$date_time)
# joining lookup table with main dataset
races <- races %>% 
  left_join(going_lookup_tbl, by = c("dg_course", "date_time")) %>% 
  mutate(
    going = coalesce(going.y, going.x),
    dg_raceid = coalesce(dg_raceid.y, dg_raceid.x)
  ) %>% 
  select(-c("going.x", "going.y", "dg_raceid.x", "dg_raceid.y")) %>% 
  select(dg_raceid, dg_course:race_distance, going, prizemoney_cent:race_type)



# Replacing still empty going strings

# dirt tracks and turf tracks
dirt_tracks <- c(
  "Cuxhaven", "Dortmund", "Honzrath", "Karlsruhe", "Neuss", "Sonsbeck", 
  "Warendorf"
)
turf_tracks <- c("Hooksiel", "Magdeburg")

races <- races %>% 
  mutate(
    going = ifelse(
      dg_course %in% dirt_tracks & going == "" & date(date_time) < "2024-05-01",
      "Boden: Sand",
      going
    ),
    going = ifelse(
      dg_course %in% turf_tracks & going == "" & date(date_time) < "2024-05-01",
      "Boden: ",
      going
    )
  )


# Adding surface column and cleaning going columns
races <- races %>%
  mutate(
    surface = case_when(
      str_detect(going, "Sand") ~ "Dirt",
      TRUE ~ "Turf"
    ),
    going = gsub("Boden: |Sand \\(|\\)|Sand", "", going) %>% na_if(., ""),
  )


##----------- Purse, Earnings ------------------------------------------------##

races <- races %>% 
  mutate(
    purse = prizemoney_cent / 100,
    earnings = str_replace_all(hoprize, " €|\\.", "") %>% 
      as.numeric(.) %>% replace_na(0)
  ) %>% 
  select(-prizemoney_cent)


##--------------- Altersklasse -----------------------------------------------##

# Vector of patterns to search for and their corresponding replacements
patterns <- c(
  "Für 2-jährige und ältere", 
  "Für 3- und 4-jährige", "Für 3- bis 5-jährige", 
  "Für 3-jährige und ältere", 
  "Für 4-jährige und ältere",
  "Für 5-jährige und ältere",
  "Für 2-jährige",
  "Für 3-jährige",
  "Für 4-jährige" 
)
replacements <- c(
  "2yo+", "3-4yo", "3-5yo", "3yo+", "4yo+", "5yo+", "2yo",  "3yo", "4yo"  
)

races$race_ages <- stri_replace_all_fixed(
  races$description, patterns, replacements, vectorize_all = FALSE
)
races$race_ages <- gsub("Innenbahn - ", "", races$race_ages)
races$race_ages <- gsub("( |,).*", "", races$race_ages)


##------------ gag_postrace --------------------------------------------------##

# races$gag_postrace <- as.numeric(
#   gsub(",", ".", str_trim(gsub(" kg", "", races$gag_postrace)))
# )


##----------- Araber- und Halbblutrennen rausfiltern -------------------------##

races <- races[grepl("Araber-Rennen", races$race_category) == 0, ]
races <- races[grepl("Halbblutrennen", races$race_category) == 0, ]

##----------- Fehler beim Scrapen bei hoage nachträglich verbessern ----------##

races$hoage <- str_extract(races$pferd_infos, "Alter: .*")
races$hoage <- str_extract(races$hoage, ".*Jahre ")
races$hoage <- gsub("Alter: ", "", races$hoage)
races$hoage <- as.integer(str_trim(gsub(" Jahre", "", races$hoage)))


##----------- position (des Pferdes Zieleinlauf) -----------------------------##

races$position <- as.integer(gsub("\\.", "", races$position))


##----------- Amateurjockey? -------------------------------------------------##

races$joam <- ifelse(grepl("^Am\\.", races$jockey), 1, 0)
races$jockey <- gsub("^Am\\.", "", races$jockey)


##----------- race_category --------------------------------------------------##

races$race_category <- str_trim(races$race_category)
# Vereinfachte Übersicht für Rennklassen einlesen
races_classes <- read.csv(
  paste0(
    "C:/Users/chris/Documents/HorseRacing/01Galopp_ver2/", 
    "02DataCleaning/race_type_class.csv"
  ), fileEncoding = "utf-8"
)
races <- merge(races, races_classes, by = c("race_category"), all.x = TRUE)
# empty strings in race_class durch NAs ersetzen
races$race_class_new <- ifelse(races$race_class_new == "", NA, races$race_class_new)
races$race_class_old <- ifelse(races$race_class_old == "", NA, races$race_class_old)


##----------------------------------------------------------------------------##
#-------------- falsche Rennzeiten ersetzen ----------------------------------##
##----------------------------------------------------------------------------##


# Bad Doberan

# 2009-08-01 18:00:00	Bad Doberan	Flachrennen	Turf	gut	2600	121.10	Ausgleich IV
# Zeit ca 171 sec
races[races$date_time == "2009-08-01 18:00:00", "race_time_secs"] <- 171


# Baden-Baden

# 2010-09-03 17:50:00	Baden-Baden	Flachrennen	Turf	gut	1600	84.01	Ausgleich IV (F)
# Zeit ca 102 sec
races[races$date_time == "2010-09-03 17:50:00", "race_time_secs"] <- 102
# 2017-05-28 15:50:00	Baden-Baden	Flachrennen	Turf	gut	2200	171.7Ausgleich II 
# Zeit ca 136 sec
races[races$date_time == "2017-05-28 15:50:00", "race_time_secs"] <- 136


# Berlin-Hoppegarten

# 2019-08-11 14:30:00 Berlin-Hoppegarten Flachrennen Turf gut 2200 82.99 Ausgleich III (E)
# Zeit ca. 143 sec
races[races$date_time == "2019-08-11 14:30:00", "race_time_secs"] <- 143
# 2019-08-11 15:05:00 Berlin-Hoppegarten Flachrennen gut 1800 Listenrennen (A)
# Zeit ca 112
races[races$date_time == "2019-08-11 15:05:00" & races$gr_course == "Berlin-Hoppegarten", "race_time_secs"] <- 112
# 2021-10-31 12:30:00 Berlin-Hoppegarten Turf gut 1200 102.98 Ausgleich III (D)
# Zeit ca 72 sec
races[races$gr_raceid == 1330240, "race_time_secs"] <- 72
# 2019-10-13 12:55:00	Berlin-Hoppegarten Flachrennen Turf gut 2200 87.59	Ausgleich IV (F)
# Zeit ca. 146 sec
races[races$date_time == "2019-10-13 12:55:00", "race_time_secs"] <- 146


# Bremen

# 2009-05-15 17:00:00 Bremen Flachrennen Turf gut 1400 (F)
# Zeit NA
races[races$date_time == "2009-05-15 17:00:00", "race_time_secs"] <- NA
# 2014-05-05 20:25:00	Bremen	Flachrennen	Turf	gut	1600	74.04	Ausgleich III (D)
# Zeit ca. 1:42:00 -> 102 sec
races[races$date_time == "2014-05-05 20:25:00", "race_time_secs"] <- 102
# 2015-06-21 17:50:00	Bremen	Flachrennen	Turf	gut	2200	86.57	(F)
# Zeit ca. 147 sec
races[races$date_time == "2015-06-21 17:50:00" & races$gr_course == "Bremen", "race_time_secs"] <- 147
# 2016-03-25 17:30:00 Bremen Flachrennen Turf weich 2600
# Zeit ca. 195 sec
races[races$date_time == "2016-03-25 17:30:00", "race_time_secs"] <- 195


# Dortmund

# 2015-10-05 19:55:00	Dortmund	Flachrennen	Sand	normal	2500	129.97	Ausgleich IV - Amateurrennen (F)
# Zeit ca 181 sec
races[races$date_time == "2015-10-05 19:55:00", "race_time_secs"] <- 181
# 2019-09-15 13:30:00 Dortmund Flachrennen gut 1600 EBF-Rennen (D)
# Zeit ca 98
races[races$date_time == "2019-09-15 13:30:00" & races$gr_course == "Dortmund", "race_time_secs"] <- 98
# 2020-09-20 17:15:00 Dortmund Flachrennen Turf gut 2000 Ausgleich IV (F)
# Zeit ca. 132 sec
races[races$date_time == "2020-09-20 17:15:00" & races$gr_course == "Dortmund", "race_time_secs"] <- 132


# Dresden

# 2020-06-13 16:00:00 Dresden Flachrennen Turf gut 1400 Ausgleich IV (F)
# Zeit ca 85 sec
races[races$date_time == "2020-06-13 16:00:00" & races$gr_course == "Dresden", "race_time_secs"] <- 85


# Frankfurt

# 2013-09-28 15:30:00	Frankfurt	Flachrennen	Turf	gut	2150	171.62	Ausgleich III
# Zeit ca 136 sec
races[races$date_time == "2013-09-28 15:30:00", "race_time_secs"] <- 136


# Gotha

# 2009-09-26 14:15:00	Gotha	Flachrennen	Turf	fest	2150	121.00	Amateurrennen (F)
# Zeit ca 134 sec
races[races$date_time == "2009-09-26 14:15:00" & races$gr_course == "Gotha", "race_time_secs"] <- 134


# Hamburg

# 2011-06-26 17:50:00	Hamburg	Flachrennen	Turf	gut	2400	120.00	Ausgleich III 
# Zeit ca 153 sec
races[races$date_time == "2011-06-26 17:50:00", "race_time_secs"] <- 153
# 2017-07-02 12:00:00 Hamburg Flachrennen Turf weich stellenweise schwer 2200 120.0 (D)
# Zeit ca. 153 sec
races[races$date_time == "2017-07-02 12:00:00", "race_time_secs"] <- 153


# Hannover

# 2015-05-25 14:20:00	Hannover	Flachrennen	Turf	gut	2200	84.86	Ausgleich III
# Zeit ca 144 sec
races[races$date_time == "2015-05-25 14:20:00", "race_time_secs"] <- 144
# 2018-04-02 18:00:00 Hannover Flachrennen Turf weich 1750 137.49 Ausgleich IV (E)
# Zeit ca. 121 sec
races[races$date_time == "2018-04-02 18:00:00", "race_time_secs"] <- 121
# 2019-04-22 14:45:00 Hannover Flachrennen Turf gut 1200 Listenrennen (A)
# Zeit ca 75 sec
races[races$date_time == "2019-04-22 14:45:00" & races$gr_course == "Hannover", "race_time_secs"] <- 75
# 2019-05-01 15:05:00 Hannover Flachrennen Turf gut bis weich 1900 Ausgleich III (D)
# Zeit ca 123
races[races$date_time == "2019-05-01 15:05:00" & races$gr_course == "Hannover", "race_time_secs"] <- 123
# 2019-05-01 15:40:00 Hannover Flachrennen Turf gut bis weich 2000 Listenrennen (A)
# Zeit ca 126
races[races$date_time == "2019-05-01 15:40:00" & races$gr_course == "Hannover", "race_time_secs"] <- 126
# 2019-10-27 11:45:00 Hannover Flachrennen Turf gut 1600 weich stellenweise schwer EBF (D)
# Zeit ca 108
races[races$date_time == "2019-10-27 11:45:00" & races$gr_course == "Hannover", "race_time_secs"] <- 108
# 2021-09-10 18:00:00 Hannover Flachrennen Turf gut bis weich 2200 Ausgleich IV (F)
# Zeit 144.18
races[races$date_time == "2021-09-10 18:00:00", "race_time_secs"] <- 144.18


# Hassloch

# 2010-05-13 14:20:00 Hassloch Flachrennen Turf gut 2200 (F)
# Zeit NA
races[races$date_time == "2010-05-13 14:20:00", "race_time_secs"] <- NA
# 2010-05-13 14:50:00 Hassloch Flachrennen Turf gut 2200 Ausgleich IV (F)
# Zeit NA
races[races$date_time == "2010-05-13 14:50:00", "race_time_secs"] <- NA
# 2018-05-10 16:55:00 Hassloch Flachrennen Turf fest 1600 187.39 Ausgleich III (E)
# Zeit ca. 138 sec
races[races$date_time == "2018-05-10 16:55:00", "race_time_secs"] <- 98


# Köln

# 2014-05-04 14:00:00 Köln Flachrennen Turf gut 1600 Ausgleich III (E)
# Zeit NA
races[races$date_time == "2014-05-04 14:00:00", "race_time_secs"] <- NA
# 2019-04-22 15:05:00 Köln Flachrennen Turf gut 1850 Ausgleich IV (E)
races[races$date_time == "2019-04-22 15:05:00" & races$gr_course == "Köln", "race_time_secs"] <- 114


# Leipzig

# 2012-09-22 16:30:00	Leipzig	Flachrennen	Turf	gut	1600	86.50	Ausgleich III (D)
# Zeit ca 99 sec
races[races$date_time == "2012-09-22 16:30:00", "race_time_secs"] <- 99
# 2019-05-01 14:10:00 Leipzig Flachrennen Turf gut 1600 (E)
# Zeit ca 98 sec
races[races$date_time == "2019-05-01 14:10:00" & races$gr_course == "Leipzig", "race_time_secs"] <- 98


# Magdeburg

# 2011-04-16 16:00:00	Magdeburg	Flachrennen	Turf	gut	2050	114.31	Ausgleich III 
# Zeit ca 128 sec
races[races$date_time == "2011-04-16 16:00:00", "race_time_secs"] <- 128
# 2016-05-22 14:05:00	Magdeburg	Flachrennen	Turf	gut	2050	114.80	Ausgleich IV 
# Zeit ca 129 sec
races[races$date_time == "2016-05-22 14:05:00", "race_time_secs"] <- 129


# Mannheim

# 2010-04-25 15:40:00 Mannheim Flachrennen Turf gut 1400 Ausgleich IV
# Zeit NA
races[races$date_time == "2010-04-25 15:40:00", "race_time_secs"] <- NA
# 2019-04-28 15:50:00 Mannheim Flachrennen Turf gut 1400 Ausgleich IV (F)
# Zeit ca 89 sec
races[races$date_time == "2019-04-28 15:50:00" & races$gr_course == "Mannheim", "race_time_secs"] <- 89


# Miesau

# 2017-08-27 15:30:00 Miesau Flachrennen Turf fest 1900 (F)
# Zeit NA
races[races$date_time == "2017-08-27 15:30:00", "race_time_secs"] <- NA


# München

# 2021-09-12 17:40:00 München Flachrennen Turf gut stellenweise fest 1600 Ausgleich III (D)
# Zeit ca. 97.03
races[races$date_time == "2021-09-12 17:40:00" & races$gr_course == "München", "race_time_secs"] <- 97.03
# 2021-09-12 16:00:00 München Turf gut stellenweise fest 2200 171.94 Ausgleich III
# Zeit ca. 142
races[races$gr_raceid == 1329726, "race_time_secs"] <- 142
# 2023-06-11 12:20:00 München Turf gut, stellenweise gut bis weich 2200 87.17 Ausgleich IV (F)
# zeit ca 148
races[races$gr_raceid == 1341220, "race_time_secs"] <- 148


# Neuss

# 2010-03-14 15:30:00	Neuss	Flachrennen	Sand	normal	1900	109.81	Ausgleich IV (F)	Ausgleich IV
# Zeit ca 134 sec
races[races$date_time == "2010-03-14 15:30:00", "race_time_secs"] <- 134
# 2012-01-15 14:00:00	Neuss	Flachrennen	Sand	normal	1100	62.11	Ausgleich IV (F)
# Zeit ca 71 sec
races[races$date_time == "2012-01-15 14:00:00", "race_time_secs"] <- 71


# Rastede

# 2019-06-16 17:20:00	Rastede	Flachrennen Turf gut 2200 127.28	(F)	
# Zeit ca. 135 sec
races[races$date_time == "2019-06-16 17:20:00", "race_time_secs"] <- 135


# Saarbrücken

# 2012-04-09 18:30:00	Saarbrücken	Flachrennen	Turf	gut	1350	60.00	(E)
# Zeit ca 82 sec
races[races$date_time == "2012-04-09 18:30:00" & races$gr_course == "Saarbrücken", "race_time_secs"] <- 82
# 2017-04-17 15:50:00	Saarbrücken	Flachrennen	Turf	gut	1900	138.72	Ausgleich IV
# Zeit ca 116 sec
races[races$date_time == "2017-04-17 15:50:00", "race_time_secs"] <- 116
# 1328390 2021-08-15 15:00:00 Saarbrücken Turf gut 1900 107.73 Ausgleich III
# Zeit ca. 114
races[races$gr_raceid == 1328390, "race_time_secs"] <- 114
# 2022-04-17 15:00:00 Saarbrücken Turf gut 1900 82.71 Ausgleich III (E)
# Zeit ca 116 sec
races[races$gr_raceid == 1333787, "race_time_secs"] <- 116


# Zweibrücken

# 2017-04-23 15:15:00 Zweibrücken Flachrennen Turf gut 2400 93.59 (F)
# Zeit ca. 154 sec
races[races$date_time == "2017-04-23 15:15:00", "race_time_secs"] <- 154
# 2021-09-11 16:15:00 Zweibrücken Flachrennen Turf gut 2400
# Zeit 153.15
races[races$date_time == "2021-09-11 16:15:00" & races$gr_course == "Zweibrücken", "race_time_secs"] <- 153.15



# Zeiten der Flachrennen auf weitere Outliers untersuchen
# nur die Zeit des Siegers wird benötigt und überflüssige Spalten löschen
flat_winningtimes <- races %>% 
  filter(
    position == 1 & !is.na(race_time_secs) & race_type == "Flachrennen" & 
      surface == "Turf" & !is.na(race_class_old)
  ) %>% 
  select(
    gr_raceid, date_time, gr_course, surface, going, 
    race_distance, race_time_secs, race_class_old
  )

# Plot: Distanzen und Zeiten der Sieger 
ggplot(flat_winningtimes, aes(x = race_distance, y = race_time_secs)) +
  geom_point(shape = 1) +
  labs(
    title = "Relationship Between Race Distance and Winning Time",
    subtitle = "German Flat Racing from 2002 to 2023"
  ) +
  xlab("Race Distance (meters)") +
  ylab("Winning Time (seconds)") +
  theme(
    plot.title = element_text(hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5)
  )

# Potentiell nicht plausible Outliers auf NA setzen
outliers <- c(
  # 1400m
  1193846, 1214861, 
  # 1500m
  1198189, 1223191, 
  # 1550m 
  1206640,
  # 1600m 
  1213661, 1193769, 1208939,
  # 2000m
  1194841,
  # 2200m
  1349913,
  # 2400m
  1214030,
  # 3050m
  1326477
)
races$race_time_secs <- ifelse(
  races$gr_raceid %in% outliers, NA, races$race_time_secs
)



##----------------------------------------------------------------------------##
##----------- späte Nichtstarter rausfiltern ---------------------------------##
##----------------------------------------------------------------------------##

races <- races[!(races$gr_raceid == 1318344 & races$gr_horseid == 25466282), ]
races <- races[!(races$gr_raceid == 1310232 & races$gr_horseid == 18568430), ]


##----------------------------------------------------------------------------##
##----------- fehlende Odds nachtragen ----- ---------------------------------##
##----------------------------------------------------------------------------##

races[races$gr_raceid == 1329144 & races$gr_horseid == 17857103, ]$odds <- 14.4
races[races$gr_raceid == 1329144 & races$gr_horseid == 23428805, ]$odds <- 6
races[races$gr_raceid == 1329144 & races$gr_horseid == 24453233, ]$odds <- 9.7
races[races$gr_raceid == 1329144 & races$gr_horseid == 25594413, ]$odds <- 4.6
races[races$gr_raceid ==  1329903 & races$gr_horseid == 29654591, ]$odds <- 14.6


##----------- Halbblut, Scheuklappen, Seitenblender, Ohrenstöpsel ------------##

# Halbblüter
races$halbblut <- as.integer(ifelse(grepl(" \\(H\\)", races$pferd), 1, 0))
races$pferd <- gsub(" \\(H\\)", "", races$pferd)
# Scheuklappen
races$skl <- as.integer(ifelse(grepl("Skl\\.", races$pferd), 1, 0))
races$pferd <- gsub("Skl\\.", "", races$pferd)
# Seitenblender
races$sb <- as.integer(ifelse(grepl("Sb\\.", races$pferd), 1, 0))
races$pferd <- gsub("Sb\\.", "", races$pferd)
# Ohrenstöpsel
races$ohrenst <- as.integer(ifelse(grepl("O\\.", races$pferd), 1, 0))
races$pferd <- gsub("O\\.", "", races$pferd)


##----------- Geschlecht des Pferdes -----------------------------------------##

races$hosex <- gsub("Geschlecht: ", "", races$hosex)


##----------- Pedigree des Pferdes -------------------------------------------##

races <- races %>% 
  mutate(
    sire_dam_split = str_split(abstammung, "\\ - "),
    sire = gsub(
      "Abstammung: v.", "", sapply(sire_dam_split, function(x) x[1]) 
    ),
    dam = sapply(sire_dam_split, function(x) x[2])
  ) %>% 
  select(-sire_dam_split)


##------------ Breeder / Züchter ---------------------------------------------##

races$breeder <- str_extract(races$pferd_infos, "<br>Züchter: .*<br>")
races$breeder <- str_remove_all(races$breeder, "Züchter: |<br>")


##----------- Abstände -------------------------------------------------------##

# bestimmte Abstände ersetzen
races$abstand[
  races$gr_raceid == 1310305 & races$position == 3 & !is.na(races$position) 
] <- "Hals (Itobo)"

# Abstand umwandeln
races$abstand_ganze_laengen <- ifelse(
  grepl("^\\d+$", races$abstand), 
  as.numeric(str_extract(races$abstand, "^\\d+$")),
  as.numeric(str_extract(races$abstand, "^\\d* "))
)
races$abstand_nachkomma <- str_extract(races$abstand, "\\d/\\d")
# Zeichen für Brüche umwandeln
races$abstand_nachkomma <- ifelse(
  grepl("^½|'½", races$abstand), "1/2", races$abstand_nachkomma
)
races$abstand_nachkomma <- ifelse(
  grepl("^¾", races$abstand), "3/4", races$abstand_nachkomma
)
races$abstand_nachkomma2 <- as.numeric(
  str_sub(races$abstand_nachkomma, 1, 1)
) / as.numeric(str_sub(races$abstand_nachkomma, 3, 3))
races$abstand_anderer <- ifelse(
  grepl("totes Rennen", races$abstand), 0,
  ifelse(
    grepl("Nase", races$abstand), 0.02,
    ifelse(
      grepl("kurzer Kopf", races$abstand), 0.05,
      ifelse(
        grepl("Kopf", races$abstand), 0.1,
        ifelse(
          grepl("Hals", races$abstand), 0.25,
          ifelse(
            grepl("Weile", races$abstand), 50, NA
          )
        )
      )
    )
  )
) 

races$abstand_ganze_laengen <- ifelse(
  is.na(races$abstand_ganze_laengen), 0, races$abstand_ganze_laengen
)
races$abstand_nachkomma2 <- ifelse(
  is.na(races$abstand_nachkomma2), 0, races$abstand_nachkomma2
)
races$abstand_anderer <- ifelse(
  is.na(races$abstand_anderer), 0, races$abstand_anderer
)
races$abstand_laengen <-  races$abstand_ganze_laengen + 
  races$abstand_nachkomma2 + races$abstand_anderer
races$abstand_laengen <- ifelse(
  is.na(races$position), NA, races$abstand_laengen
)
# überflüssige Spalten rausschmeißen
races <- races %>% 
  select(
    - c(
      abstand_ganze_laengen, abstand_nachkomma, 
      abstand_nachkomma2, abstand_anderer
    )
  )

# Abstand in Zeit umwandeln
races$abstand_zeit <- races$abstand_laengen * 0.144
races <- races %>% 
  arrange(position) %>% 
  group_by(gr_raceid) %>% 
  mutate(abstand_zeitcum = cumsum(abstand_zeit))
# Zeit für jedes Pferd berechnen
races$zeit_pferd <- races$abstand_zeitcum + races$race_time_secs



##----------- data frame als csv abspeichern ---------------------------------##

write.csv(
  races,
  paste0(
    "C:/Users/chris/Documents/HorseRacing/01Galopp_ver2/", 
    "02DataCleaning/galopp_de_clean.csv"
  ),
  row.names = FALSE, fileEncoding = "utf-8"
)


