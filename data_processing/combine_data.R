library(tidyverse)


##----------- Renninfos einlesen ---------------------------------------------##

raceinfos_csvs <- list.files(
  paste0(
    "C:/Users/chris/Documents/HorseRacing/01Galopp_ver2",
    "/01DataCollection/01RaceInfos/01Rohdaten"  
  ),
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)


raceinfos_df_list <- lapply(
  raceinfos_csvs, 
  read.csv,
  header = FALSE,
  col.names = c(
    'gr_raceid', 'gr_course', 'race_name', 'gr_title', 
    'race_no', 'date_time', 'race_category', 'race_distance', 
    'prizemoney_cent', 'going', 'description', 'facts', 
    'race_time_secs', 'zw', 'dw', 'vw'
  ),
  colClasses = c(rep("character", 16)),
  encoding = "utf-8"
)

# raceinfos zu einem data frame verbinden
raceinfos <- bind_rows(raceinfos_df_list)


## raceinfos-Spalten auf Konsistenz überprüfen

# gr_raceid: Zeilen rausfiltern die nicht mit "1" in gr_raceid beginnen
raceinfos_grraceid_nostartwith_1 <- raceinfos %>% 
  filter(!grepl("^1", gr_raceid))

# gr_course
sort(unique(raceinfos$gr_course))

# race_no
sort(as.integer(unique(raceinfos$race_no)))

# date_time
raceinfos_datetime_nostartwith_20 <- raceinfos %>% 
  filter(!grepl("^20", date_time))

# race_category
sort(unique(raceinfos$race_category))

# race_distance
sort(as.numeric(unique(raceinfos$race_distance)))

# prizemoney_cent
sort(as.integer(unique(raceinfos$prizemoney_cent)))

# going
sort(unique(raceinfos$going))

# description
raceinfos %>% 
  filter(!grepl("^Für", description))
# Fehlende Infos ergänzen:
# Berlin-Hoppegarten R2, 2003-05-18
desc_string <- paste0(
  "Für 3-jährige und ältere Pferde, Gew. 58,0 kg. Pferden, die 2003 kein ", 
  "zweites Platzgeld gewonnen haben, 1 kg, weder ein zweites noch ", 
  "drittes Platzgeld, 2 kg erl."
)
raceinfos$description <- ifelse(
  raceinfos$gr_raceid == 1195815, desc_string, raceinfos$description
)
# Hannover R1, 2004-09-12
desc_string <- paste0(
  "Für 3-jährige und ältere Pferde, Gew. 60,0 kg. f.3j., 64,0 kg. f.4j.,", 
  " 66,0 kg. f.5j.u.ält. Für jeden Sieg 2 kg mehr. 4-jährigen und älteren ",
  "Halbblutpferden, die keinen Geldpreis von 400 € gewonnen haben 2 kg erl."
)
raceinfos$description <- ifelse(
  raceinfos$gr_raceid == 1203938, desc_string, raceinfos$description
)

# facts
raceinfos_facts_notstartwith_quoten <- raceinfos %>% 
  filter(!grepl("^Quoten", facts))

# race_time_secs
raceinfos %>% 
  filter(!grepl("^[0-9]", race_time_secs) & !grepl("^$", race_time_secs))
raceinfos %>% 
  filter(grepl(",", race_time_secs))

# zw
raceinfos %>% 
  filter(!grepl("^[0-9]", zw) & !grepl("^$", zw))
raceinfos %>% 
  filter(grepl(",", zw))

# dw
raceinfos %>% 
  filter(!grepl("^[0-9]", dw) & !grepl("^$", dw))
raceinfos %>% 
  filter(grepl(",", dw))

# vw
raceinfos %>% 
  filter(!grepl("^[0-9]", vw) & !grepl("^$", vw))
raceinfos %>% 
  filter(grepl(",", vw))


# Spalten: Data Types anpassen
# gr_raceid --> integer
# gr_course --> character
# race_name --> character
# gr_title --> character
# race_no --> integer
# date_time --> date
# race_category --> character
# race_distance --> numeric
# prizemoney_cent --> integer
# going --> character
# description --> character
# facts --> character
# race_time_secs numeric
# zw --> numeric
# dw --> numeric
# vw --> numeric

# change column data types to integer
raceinfos <- raceinfos %>% 
  mutate(across(c(gr_raceid, race_no, prizemoney_cent), as.integer))
# change column data types to numeric
raceinfos <- raceinfos %>% 
  mutate(across(c(race_distance, race_time_secs, zw, dw, vw), as.numeric))

# Duplikate suchen
duplicates <- raceinfos %>% 
  group_by(gr_raceid) %>% 
  filter(n() > 1) %>% 
  ungroup()


# aufräumne
rm(list = setdiff(ls(), "raceinfos"))



##----------- Rennresultate einlesen -----------------------------------------##

raceresults_csvs_list <- list.files(
  paste0(
    "C:/Users/chris/Documents/HorseRacing/01Galopp_ver2/", 
    "01DataCollection/02RaceResults/01Rohdaten"
  ),
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

# Rohdaten mit Rennresultaten laden (csvs mit "," als sep)
# odds als col_character() einlesen und später umwandeln
raceresults_df_list <- lapply(
  raceresults_csvs_list,
  read_delim, delim = ",",
  col_names = c(
    "gr_raceid", "position", "pferd", "gr_horseid",
    "pferd_infos", "abstammung", "hosex", "hoage",
    "hono", "hobox", "abstand", "gewinn", 
    "besitzer", "trainer", "jockey", "gewicht",
    "odds"
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

raceresults <- bind_rows(raceresults_df_list)

# odds Spalte anpassen (whitespace trim und Komma ersetzen)
raceresults$odds <- str_trim(raceresults$odds)
raceresults$odds <- as.double(gsub(",", ".", raceresults$odds))




# aufräumen
rm(list = setdiff(ls(), c("raceinfos", "raceresults")))



##---------- Renninfos und Rennresultate verbinden ---------------------------##

# Welche race_ids fehlen in raceinfos, die jedoch in raceresults vorhanden sind
# und umgekehrt
setdiff(raceresults$gr_raceid, raceinfos$gr_raceid)
setdiff(raceinfos$gr_raceid, raceresults$gr_raceid)

#raceids die in raceinfos vorhanden sind aber nicht raceresults sind Rennen, die
# nicht gelaufen worden sind

races <- raceinfos %>% 
  inner_join(raceresults, by = "gr_raceid")


# 
# 
# ##----------- GAGs einlesen --------------------------------------------------##
# 
# gag_20160101bis20210930 <- read.csv2(
#   paste0(
#     "C:/Users/luise/Documents/Christian/HorseRacing/01Galopp_ver2/", 
#     "01DataCollection/03GAG/horses_GAG_20160101bis20210930.csv"    
#   )
# )
# 
# # Spalte gr_raceid auf id reduzieren
# gag_20160101bis20210930$gr_raceid <- gsub(
#   "^.*id=", "", gag_20160101bis20210930$gr_raceid
# )
# gag_20160101bis20210930$gr_raceid <- gsub(
#   "&d=.*$", "", gag_20160101bis20210930$gr_raceid
# )
# gag_20160101bis20210930$gr_raceid <- as.integer(
#   gag_20160101bis20210930$gr_raceid
# )
# # Duplikate in GAGs rausfiltern
# gag_20160101bis20210930 <- distinct(
#   gag_20160101bis20210930, gr_raceid, gr_horseid, .keep_all = TRUE
# )
# 
# 
# ##----------- Rennen und GAGs verbinden --------------------------------------##
# 
# races_2002bis2023 <- races_2002bis2023 %>% 
#   left_join(gag_20160101bis20210930, by = c("gr_raceid", "gr_horseid"))
# # aufräumen
# rm(
#   list = c(
#     "gag_20160101bis20210930", "raceinfos_2002bis2023", 
#     "raceresults_2002bis2023"
#   )
# )


##----------- Duplikate in races finden und entfernen ------------------------##

races_duplicates <- races[duplicated(races), ]

races <- races %>% distinct()


##----------- data frame als csv speichern -----------------------------------##

write.csv(
  races,
  paste0(
    "C:/Users/chris/Documents/HorseRacing/01Galopp_ver2/", 
    "01DataCollection/galopp_de.csv"    
  ),
  row.names = FALSE,
  fileEncoding = "utf-8"
)






