library(tidyverse)


##------------- Import raceinfos ---------------------------------------------##


# set working directory to directory in which script is stored
script_path <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_path)

# Fetch paths of csv files with race infos
rinfos_csvs_path <- list.files(
  "../data/raw/race_infos", pattern = "\\.csv$", 
  full.names = TRUE, recursive = TRUE
)

raceinfos_df_list <- lapply(
  rinfos_csvs_path, 
  read.csv,
  header = FALSE,
  col.names = c(
    'dg_raceid', 'dg_course', 'race_name', 'dg_title', 'race_no', 'date_time', 
    'race_category', 'race_distance', 'prizemoney_cent', 'going', 'description', 
    'facts', 'race_time_secs', 'exacta', 'trifecta', 'superfecta'
  ),
  colClasses = c(rep("character", 16)),
  encoding = "utf-8"
)

# combine list of dfs into on data frame
raceinfos <- bind_rows(raceinfos_df_list)


##------------- Checking raceinfos columns for consistency -------------------##
##-------------------and some minor cleaning tasks ---------------------------##

# gr_course
sort(unique(raceinfos$dg_course))

# race_no
sort(as.integer(unique(raceinfos$race_no)))

# date_time
raceinfos_datetime_nostartwith_20 <- raceinfos %>% 
  filter(!grepl("^20", date_time))
unique(nchar(raceinfos$date_time))

# race_category
sort(unique(raceinfos$race_category))

# race_distance
sort(as.numeric(unique(raceinfos$race_distance)))

# prizemoney_cent
sort(as.integer(unique(raceinfos$prizemoney_cent)))

# going
sort(unique(raceinfos$going))

# description
unusual_description <- raceinfos %>% 
  filter(!grepl("^Für", description))
innenbahn <- raceinfos %>% 
  filter(grepl("Innenbahn", description))
raceinfos$inner_track <- grepl("Innenbahn", raceinfos$description)
raceinfos$description <- gsub("^Innenbahn - ", "", raceinfos$description)
# Add missing descriptions:
# Berlin-Hoppegarten R2, 2003-05-18
desc_string <- paste0(
  "Für 3-jährige und ältere Pferde, Gew. 58,0 kg. Pferden, die 2003 kein ", 
  "zweites Platzgeld gewonnen haben, 1 kg, weder ein zweites noch ", 
  "drittes Platzgeld, 2 kg erl."
)
raceinfos$description <- ifelse(
  raceinfos$dg_raceid == 1195815, desc_string, raceinfos$description
)
# Hannover R1, 2004-09-12
desc_string <- paste0(
  "Für 3-jährige und ältere Pferde, Gew. 60,0 kg. f.3j., 64,0 kg. f.4j.,", 
  " 66,0 kg. f.5j.u.ält. Für jeden Sieg 2 kg mehr. 4-jährigen und älteren ",
  "Halbblutpferden, die keinen Geldpreis von 400 € gewonnen haben 2 kg erl."
)
raceinfos$description <- ifelse(
  raceinfos$dg_raceid == 1203938, desc_string, raceinfos$description
)

# facts
raceinfos_facts_notstartwith_quoten <- raceinfos %>% 
  filter(!grepl("^Quoten", facts))

# race_time_secs
raceinfos %>% 
  filter(!grepl("^[0-9]", race_time_secs) & !grepl("^$", race_time_secs))
raceinfos %>% 
  filter(grepl(",", race_time_secs))

# exacta
raceinfos %>% 
  filter(!grepl("^[0-9]", exacta) & !grepl("^$", exacta))
raceinfos %>% 
  filter(grepl(",", exacta))

# trifecta
raceinfos %>% 
  filter(!grepl("^[0-9]", trifecta) & !grepl("^$", trifecta))
raceinfos %>% 
  filter(grepl(",", trifecta))

# superfecta
raceinfos %>% 
  filter(!grepl("^[0-9]", superfecta) & !grepl("^$", superfecta))
raceinfos %>% 
  filter(grepl(",", superfecta))

# change column data types to integer
raceinfos <- raceinfos %>% 
  mutate(across(c(dg_raceid, race_no, prizemoney_cent), as.integer))
# change column data types to numeric
raceinfos <- raceinfos %>% 
  mutate(
    across(
      c(race_distance, race_time_secs, exacta, trifecta, superfecta), 
      as.numeric
    )
  )

# search duplicates
duplicates <- raceinfos %>% 
  group_by(dg_raceid) %>% 
  filter(n() > 1) %>% 
  ungroup()

# remove unnecessary variables
rm(list = setdiff(ls(), "raceinfos"))



##----------- Import race results --------------------------------------------##

# Fetch paths of csv files with race infos
rresults_csvs_path <- list.files(
  "../data/raw/race_results", pattern = "\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

# create list with results data frames
raceresults_df_list <- lapply(
  rresults_csvs_path,
  read_delim, delim = ",",
  col_names = c(
    "dg_raceid", "position", "horse", "dg_horseid", "horse_infos", "pedigree", 
    "hosex", "hoage", "hono", "hostall", "dist_btn_chr", "hoprize", 
    "owner", "trainer", "jockey", "weight_chr", "odds"
  ),
  col_types = list(
    col_integer(), col_character(), col_character(), col_integer(),
    col_character(), col_character(), col_character(), col_character(),
    col_integer(), col_integer(), col_character(), col_character(),
    col_character(), col_character(), col_character(), col_character(),
    col_character()
  ),
  locale = locale(decimal_mark = ",")
)

# combine results dfs
raceresults <- bind_rows(raceresults_df_list)

# odds colum trim whitespace trim and replace comma
raceresults$odds <- str_trim(raceresults$odds)
raceresults$odds <- as.double(gsub(",", ".", raceresults$odds))

# remove unnecessary variables
rm(list = setdiff(ls(), c("raceinfos", "raceresults")))



##---------- Combine race infos and race results -----------------------------##

# Finding race_ids missing in raceinfos but not in raceresults and vice versa
setdiff(raceresults$dg_raceid, raceinfos$dg_raceid)
setdiff(raceinfos$dg_raceid, raceresults$dg_raceid)

# combining raceinfos and raceresults
races <- raceinfos %>% 
  inner_join(raceresults, by = "dg_raceid")



##----------- Find duplicates and remove them --------------------------------##

races_duplicates <- races[duplicated(races), ]
races <- races %>% distinct()



##----------- Save as RData file ---------------------------------------------##

saveRDS(races, "../data/intermediate/im_german_racing_data.RData")

rm(list = ls())

