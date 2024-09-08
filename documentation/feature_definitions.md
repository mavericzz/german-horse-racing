# Feature Definitions for German Horse Racing 

This document provides definitions for the features engineered in the script for analyzing German horse racing data. The features are categorized as horse features and jockey features.

## Horse Features:
* win (dependent variable): A binary variable indicating whether the horse won the race (1) or not (0).
* hoattend: Counter for the number of races the horse has participated in (excluding the current race).
* hoattend_turf: Number of previous races on turf surfaces (excluding the current race).
* hoattend_dirt: Number of previous races on dirt surfaces (excluding the current race).
* hoattend365: Number of races participated in within the last 365 days (excluding the current race).
* hoattend730: Number of races participated in within the last 730 days (excluding the current race).
* hofirstrace: Binary variable indicating whether this is the horse's first race (1) or not (0).
* howins: Total number of wins by the horse up to the previous race (excluding the current race).
* howins730: Total number of wins by the horse in the last 730 days (excluding the current race).
* howins_turf: Total number of wins on turf surfaces by the horse up to the previous race (excluding the current race).
* howins_dirt: Total number of wins on dirt surfaces by the horse up to the previous race (excluding the current race).
* hosr: Win strike rate of the horse, calculated as total wins divided by the number of races participated in (excluding the current race).
* hosr_turf: Win strike rate of the horse on turf surfaces, calculated as total wins on turf divided by the number of races on turf (excluding the current race).
* hosr_dirt: Win strike rate of the horse on dirt surfaces, calculated as total wins on dirt divided by the number of races on dirt (excluding the current race).
* hosr730: Win strike rate of the horse within the last 730 days, calculated as total wins in the last 730 days divided by the number of races in the last 730 days (excluding the current race).
* hoearnings: Total earnings of the horse up to the previous race (excluding the current race).
* hoearnings_turf: Total earnings of the horse on turf surfaces up to the previous race (excluding the current race).
* hoearnings_dirt: Total earnings of the horse on dirt surfaces up to the previous race (excluding the current race).
* hoearnings365: Total earnings of the horse in the last 365 days (excluding the current race).
* homeanearn: Average earnings per race of the horse, calculated as total earnings divided by the number of races participated in (excluding the current race).
* homeanearn_turf: Average earnings per race on turf surfaces of the horse, calculated as total earnings on turf divided by the number of races on turf (excluding the current race).
* homeanearn_dirt: Average earnings per race on dirt surfaces of the horse, calculated as total earnings on dirt divided by the number of races on dirt (excluding the current race).
* homeanearn365: Average earnings per race of the horse in the last 365 days, calculated as total earnings in the last 365 days divided by the number of races in the last 365 days (excluding the current race).
* hosprat: Speed rating of the horse based on the course record and the horse's finishing time, adjusted to be non-negative.
* holastsprat: Speed rating of the horse in the previous race.
* homean4sprat: Average speed rating of the horse in the last 4 races (including the current race).

## Jockey Features

* joattend: Counter for the number of races the jockey has participated in (excluding the current race).
* joattend_turf: Number of previous races ridden by the jockey on turf surfaces (excluding the current race).
* joattend_dirt: Number of previous races ridden by the jockey on dirt surfaces (excluding the current race).
* joattend365: Number of races ridden by the jockey within the last 365 days (excluding the current race).
* jowins: Total number of wins by the jockey up to the previous race (excluding the current race).
* jowins_turf: Total number of wins on turf surfaces by the jockey up to the previous race (excluding the current race).
* jowins_dirt: Total number of wins

