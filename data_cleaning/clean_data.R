library(lubridate)
library(stringi)
library(tidyverse)


##----------- Import Data ----------------------------------------------------##

# set working directory to directory in which script is stored
script_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_path)

races <- readRDS("../data/intermediate/im_german_racing_data.Rds")



##----------------------------------------------------------------------------##
##----------- Format, clean, and add columns ---------------------------------##
##----------------------------------------------------------------------------##


##-------------------------- date_time column --------------------------------##
races$date_time <- ymd_hms(races$date_time)


##----------- Hurdle races, steeplechase and flat racing ---------------------##

# Variable race_type
races$race_type <- ifelse(
  grepl("Huerdenrennen", races$race_category),
  "hurdle",
  ifelse(
    grepl("Jagdrennen", races$race_category), "chase","flat"
  )
)


##----------- Replace incorrect horse names ----------------------------------##

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


##----------- exclude late Non-Runners ---------------------------------------##

races <- races[!(races$dg_raceid == 1318344 & races$dg_horseid == 25466282), ]
races <- races[!(races$dg_raceid == 1310232 & races$dg_horseid == 18568430), ]
races <- races[!(races$dg_raceid == 1293355 & races$dg_horseid == 24808977), ]

##----------- Replace missing odds with values -------------------------------##

races[races$dg_raceid == 1329144 & races$dg_horseid == 17857103, ]$odds <- 14.4
races[races$dg_raceid == 1329144 & races$dg_horseid == 23428805, ]$odds <- 6
races[races$dg_raceid == 1329144 & races$dg_horseid == 24453233, ]$odds <- 9.7
races[races$dg_raceid == 1329144 & races$dg_horseid == 25594413, ]$odds <- 4.6
races[races$dg_raceid ==  1329903 & races$dg_horseid == 29654591, ]$odds <- 14.6


##----------- Half-bred, blinkers, cheekpieces, earplugs ---------------------##

# Half-bred
races$halfbred <- as.integer(ifelse(grepl(" \\(H\\)", races$horse), 1, 0))
races$horse <- gsub(" \\(H\\)", "", races$horse)
# blinkers
races$blinkers <- as.integer(ifelse(grepl("Skl\\.", races$horse), 1, 0))
races$horse <- gsub("Skl\\.", "", races$horse)
# cheekpieces
races$cheekpieces <- as.integer(ifelse(grepl("Sb\\.", races$horse), 1, 0))
races$horse <- gsub("Sb\\.", "", races$horse)
# earplugs
races$earplugs <- as.integer(ifelse(grepl("O\\.", races$horse), 1, 0))
races$horse <- gsub("O\\.", "", races$horse)


##------------------- Horse's gender -----------------------------------------##

races$hosex <- gsub("Geschlecht: ", "", races$hosex)


##------------------ Pedigree (Sire and Dam) ---------------------------------##

races <- races %>% 
  mutate(
    sire_dam_split = str_split(pedigree, "\\ - "),
    sire = gsub(
      "Abstammung: v.", "", sapply(sire_dam_split, function(x) x[1]) 
    ),
    dam = sapply(sire_dam_split, function(x) x[2])
  ) %>% 
  select(-sire_dam_split)


##---------------------- Breeder ---------------------------------------------##

races$breeder <- str_extract(races$horse_infos, "<br>Züchter: .*<br>")
races$breeder <- str_remove_all(races$breeder, "Züchter: |<br>")


##---------------------------- Distance beaten -------------------------------##

# replace margin values
races$dist_btn_chr[
  races$dg_raceid == 1310305 & races$position == 3 & !is.na(races$position) 
] <- "Hals (Itobo)"

# transform dist_btn_chr
races$dist_btn_whole_lengths <- ifelse(
  grepl("^\\d+$", races$dist_btn_chr), 
  as.numeric(str_extract(races$dist_btn_chr, "^\\d+$")),
  as.numeric(str_extract(races$dist_btn_chr, "^\\d* "))
)
races$dist_btn_fractional_part <- str_extract(races$dist_btn_chr, "\\d/\\d")
# transform signs for fractions
races$dist_btn_fractional_part <- ifelse(
  grepl("^½|'½", races$dist_btn_chr), "1/2", races$dist_btn_fractional_part
)
races$dist_btn_fractional_part <- ifelse(
  grepl("^¾", races$dist_btn_chr), "3/4", races$dist_btn_fractional_part
)
races$dist_btn_fractional_part2 <- as.numeric(
  str_sub(races$dist_btn_fractional_part, 1, 1)
) / as.numeric(str_sub(races$dist_btn_fractional_part, 3, 3))
races$dist_btn_other <- ifelse(
  grepl("totes Rennen", races$dist_btn_chr), 0,
  ifelse(
    grepl("Nase", races$dist_btn_chr), 0.02,
    ifelse(
      grepl("kurzer Kopf", races$dist_btn_chr), 0.05,
      ifelse(
        grepl("Kopf", races$dist_btn_chr), 0.1,
        ifelse(
          grepl("Hals", races$dist_btn_chr), 0.25,
          ifelse(
            grepl("Weile", races$dist_btn_chr), 50, NA
          )
        )
      )
    )
  )
) 

races$dist_btn_whole_lengths <- ifelse(
  is.na(races$dist_btn_whole_lengths), 0, races$dist_btn_whole_lengths
)
races$dist_btn_fractional_part2 <- ifelse(
  is.na(races$dist_btn_fractional_part2), 0, races$dist_btn_fractional_part2
)
races$dist_btn_other <- ifelse(
  is.na(races$dist_btn_other), 0, races$dist_btn_other
)
races$dist_btn <-  races$dist_btn_whole_lengths + 
  races$dist_btn_fractional_part2 + races$dist_btn_other
races$dist_btn <- ifelse(
  is.na(races$position), NA, races$dist_btn
)
# remove unnecessary columns
races <- races %>% 
  select(
    - c(
      dist_btn_whole_lengths, dist_btn_fractional_part, 
      dist_btn_fractional_part2, dist_btn_other
    )
  )
# distance to the winner, measure distance in time
races <- races %>% 
  arrange(position) %>% 
  group_by(dg_raceid) %>% 
  mutate(
    dist_btn_cum = cumsum(dist_btn),
    secs_btn = dist_btn * 0.1667,
    secs_btn_cum = cumsum(secs_btn),
    # time for each horse
    hotime = secs_btn_cum + race_time_secs
  )


##---------------------------- Weight ----------------------------------------##

# correction of errors in weight_chr
races$weight_chr <- ifelse(
  races$dg_raceid == 1187949 & races$dg_horseid == 1828245, 
  "56,0 kgErl. 3,0", 
  races$weight_chr
)

# splitting weight_chr into three new columns (weight, allowance, penalty)
races <- races %>% 
  mutate(
    weight = gsub(" kg.*", "", weight_chr),
    weight = as.numeric(str_replace(weight, ",", "\\.")),
    weight_penalty = ifelse(
      grepl("Mgw.", weight_chr), gsub(".*Mgw. ", "", weight_chr), "0"
    ),
    weight_penalty = as.numeric(str_replace(weight_penalty, ",", "\\.")),
    weight_allowance = ifelse(
      grepl("Erl.", weight_chr), gsub(".* kgErl. |Mgw.*", "", weight_chr), "0"
    ),
    weight_allowance = as.numeric(str_replace(weight_allowance, ",", "\\."))
  )
  

##------------------------------ Odds ----------------------------------------##

odds_below_one <- races %>% 
  filter(odds < 1) %>% 
  select(dg_raceid, date_time, horse, dg_horseid)

# import lookup table
odds_lookup_tbl <- read.csv("../data/raw/odds_corrections.csv") %>% 
  select(dg_raceid, dg_horseid, odds)
# joining lookup table with main dataset
races <- races %>% 
  left_join(odds_lookup_tbl, by = c("dg_raceid", "dg_horseid")) %>% 
  mutate(
    odds = coalesce(odds.y, odds.x)
  ) %>% 
  select(-c("odds.x", "odds.y")) 

# races with wrong odds --> set odds to NA
# dg_raceids
races_wrong_odds <- c(
  1277400, 1276887, 1277570
)


races <- races %>% 
  mutate(
    weightadj3yo = str_extract(
      description,
      "GAG\\s*([+-]?\\d+,?\\d*)\\s*f\\.3j\\."
    ),
    weightadj3yo = as.numeric(
      str_replace(
        str_replace_all(weightadj3yo, "GAG\\s*|\\s*f\\.3j\\.", ""),
        ",", "."
      )
    ),
    weightadj4yoplus = str_extract(
      description,
      "([+-]?\\d+,?\\d*)\\s*f\\.4j\\.u\\.ält\\."
    ),
    weightadj4yoplus = as.numeric(
      str_replace(
        str_replace_all(weightadj4yoplus, "\\s*f\\.4j\\.u\\.ält\\.", ""),
        ",", "."
      )
    )
  ) %>% 
  mutate_at(
    vars(weightadj3yo, weightadj4yoplus), ~replace_na(., 0)
  ) %>% 
  mutate(
    gag = ifelse(
      hoage <= 3,
      weight + weight_allowance - weight_penalty - weightadj3yo,
      weight + weight_allowance - weight_penalty - weightadj4yoplus
    )  
  )





##----------- Save data frame as RData file ----------------------------------##

saveRDS(races, "../data/processed/cleaned_german_racing_data.Rds")

