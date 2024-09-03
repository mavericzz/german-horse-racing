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


##--------------- Age Groups -------------------------------------------------##

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


##----------- Filtering out non thoroughbred races ---------------------------##


races <- races %>% 
  filter(!grepl("Araber-Rennen|Halbblutrennen", race_category))


##--------------------------- Age column -------------------------------------##

races$hoage <- str_extract(races$horse_infos, "Alter: .*")
races$hoage <- str_extract(races$hoage, ".*Jahre ")
races$hoage <- gsub("Alter: ", "", races$hoage)
races$hoage <- as.integer(str_trim(gsub(" Jahre", "", races$hoage)))


##----------- Finish position ------------------------------------------------##

races$position <- as.integer(gsub("\\.", "", races$position))


##-------------------- Amateur jockey? ---------------------------------------##

races$joam <- ifelse(grepl("^Am\\.", races$jockey), 1, 0)
races$jockey <- gsub("^Am\\.", "", races$jockey)


##----------- race_category --------------------------------------------------##

races$race_category <- str_trim(races$race_category)
# import race class table
races_classes <- read.csv(
  "../data/raw/race_type_class.csv", fileEncoding = "utf-8"
)
races <- merge(races, races_classes, by = c("race_category"), all.x = TRUE)
# replace empty strings in race_class with NAs
races$race_class_new <- ifelse(
  races$race_class_new == "", NA, races$race_class_new
)
races$race_class_old <- ifelse(
  races$race_class_old == "", NA, races$race_class_old
)


##------------------------- Winning Times ------------------------------------##
##----------- Adding missing and replacing wrong winning times ---------------##

# import lookup table
times_lookup_tbl <- read.csv("../data/raw/race_time_corrections.csv")
# change NAs to 0
times_lookup_tbl$race_time_secs <- ifelse(
  is.na(times_lookup_tbl$race_time_secs), 0, times_lookup_tbl$race_time_secs
)
times_lookup_tbl$date_time <- ymd_hms(times_lookup_tbl$date_time)
# joining lookup table with main dataset
races <- races %>% 
  left_join(times_lookup_tbl, by = c("dg_raceid", "dg_course", "date_time")) %>% 
  mutate(
    race_time_secs = coalesce(race_time_secs.y, race_time_secs.x),
    race_time_secs = if_else(race_time_secs == 0, NA, race_time_secs)
  ) %>% 
  select(-c("race_time_secs.x", "race_time_secs.y"))

# Checking for remaining outliers in race_time_secs
flat_winningtimes <- races %>% 
  filter(
    position == 1 & !is.na(race_time_secs) & race_type == "flat" & 
      surface == "Turf" & !is.na(race_class_old)
  ) %>% 
  select(
    dg_raceid, date_time, dg_course, surface, going, 
    race_distance, race_time_secs, race_class_old
  )
# Plot: Distances and winning times
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


