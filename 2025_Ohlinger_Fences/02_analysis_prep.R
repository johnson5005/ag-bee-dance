###############################################################################
## 02 Analysis  Preparation                                                  ##
## This script imports the data and                                          ##
## prepares it for the primary analysis                                      ##
## Author: Bradley Ohlinger and Roger Schürch                                ##
###############################################################################

# MIT License 
# 
# Copyright (c) [2025] [Bradley Ohlinger] 
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of 
# this software and associated documentation files (the "Software"), to deal in the
# Software without restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so, subject to the
# following conditions:
# 
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

source("./scripts/00_system_prep.R") # loads necessary packages
source("./scripts/01_dance_data_prep.R") # loads
# and formats data

## First, set your working directory to the foraging_cluster_analysis folder

## Here we load and prepare the data for analysis at three sites

for (i in c("blacksburg", "tidewater", "winchester")){
  current_site <- i # specifies field site
  current_hives <- paste0(substring(current_site, 1, 1), c("a", "b", "c")) # specifies hives
  
  ## Now let's read in some data. This is dataset was prepared via 01_dance_data_prep
  ## and contains a single mean waggle run duration and angle for each decoded 
  ## waggle dance.
  
  data_agg <- read.csv("./csv/dance_agg_data.csv")
  data_agg$dt <- strptime(as.character(data_agg$dt), format = "%Y-%m-%d %H:%M:%S")
  data_agg <- data_agg[data_agg$HiveID %in% current_hives,] # select only data from current hives
  
  # Let's get the coordinates for the colonies so we can calculate distance below
  mean_hive_easting <- mean(unique(data_agg[,"easting"]))
  mean_hive_northing <- mean(unique(data_agg[,"northing"]))
  
  # We will also want the CRS string to project the points
  crs_string <- as.character(unique(data_agg$crs.string))

  # Now let's load the simulated points. These points were simulated 
  # in a previous publication. The necessary calibration data and scripts can
  # be found online (website: https://data.lib.vt.edu/, doi:10.7294/20498757).
  
  load(file.path("./points",
                 paste0("Allsample.", current_site, "_points.RData")))
  
  total_points <- total.points # data loads as total.points by default
  # but we rename to be consistent with our naming convention
  
  # here we calculate foraging distance based on dance coordinates
  total_points$Distance <- sqrt((total_points$easting - mean_hive_easting)^2 +
                                  (total_points$northing - mean_hive_northing)^2)
  
  # here we merge data_agg to total_points to associate the relevant date and hive information
  total_points <- 
    merge(total_points, data_agg[,c("DanceID", "HiveID", "dt")], by = "DanceID")
  total_points$Date <- format(total_points$dt, "%Y-%m-%d")
  total_points$HiveID <- as.factor(total_points$HiveID)
  
  ## Here we convert from data_frame to a spatial points data frame
  ## and project the data appropriately.
  
  total_points <-
    SpatialPointsDataFrame(coordinates(total_points[,c("easting", "northing")]),
                           data = total_points)
  proj4string(total_points) <- CRS(crs_string)
  
  assign(paste(substr(i,1,1), "total_points", sep = "_"), total_points)
}

## Below we select the appropriate data for the inter-dance distance,
## k-nearest neighbor, and k-means cluster analyses. For these
## analyses, we use only the data from dates where at least two colonies
## performed two or more dances. 

## First, we have to select only the dates that have dances from 
## more than one colony. These are the dates that allow for comparisons

b_agg <- aggregate(list(Hive = as.character(b_total_points$HiveID)),
                   by = list(Date = b_total_points$Date),
                   function(x) length(unique(x)))

b_agg <- b_agg[b_agg$Hive > 1,]
table(b_agg$Hive)

bb_points <- 
  b_total_points[b_total_points$Date %in% unique(b_agg$Date),]


## Now we have to check to make sure all of the dates 
## have more than one dance from each of the colonies.
## This is required for calculating within colony 
## inter-dance distances.

bb_count <- aggregate(DanceID ~ Date + HiveID, data = bb_points,
                    FUN = function(x) length(unique(x)))
colnames(bb_count) <- c("date", "hive", "count") 
bb_single <- bb_count[bb_count$count == 1,]
print(bb_single)

## Now we know which date x colony combinations have only a single dance.
## In particular, 2018-10-08 bc has a single dance. We need to determine 
## how many colonies had dances on this date. We can keep this date and 
## simply remove the single dance from bc if there are three colonies.

length(unique(bb_points@data[bb_points@data$Date == "2018-10-08","HiveID"]))

## There are only two colonies on this day, so let's remove the data from this day
## because no within versus between comparison can be made.

bb_points <- bb_points[bb_points$Date != "2018-10-08",]

## bb_points is now ready for the inter-dance distance and k-nearest neighbor
## analyses. However, for the k-mean cluster analysis, we want to have an idea 
## of how many dances there are on each individual day

bb_dance_count <- aggregate(list(dance_count = bb_points$DanceID), 
                      by = list(date = bb_points$Date), length)

range(bb_dance_count$dance_count)

## Dates have 7-71 dances at the blacksburg site.

## Tidewater

## Let's select only data from dates with dances from more than one colony.

t_agg <- aggregate(list(Hive = as.character(t_total_points$HiveID)),
                   by = list(Date = t_total_points$Date),
                   function(x) length(unique(x)))

t_agg <- t_agg[t_agg$Hive > 1,]
table(t_agg$Hive)

tw_points <- 
  t_total_points[t_total_points$Date %in% unique(t_agg$Date),]
 
## Now we have to check for dates with a colonies that only 
## danced once. These dates will not allow for within versus 
## between comparisons, so they need to be removed.

tw_count <- aggregate(DanceID ~ Date + HiveID, data = tw_points,
                      FUN = function(x) length(unique(x)))
colnames(tw_count) <- c("date", "hive", "count") 
tw_single <- tw_count[tw_count$count == 1,]
print(tw_single)

## There are 11 days with only one dance from one of the colonies.
## None of these dates have two colonies with only one dance.

## Now we need to determine if these dates contain data from three colonies or 
## two colonies. The dates with only two colonies cannot be used. 

remove_date <- vector()
remove_hive <- vector()
for (i in tw_single$date){
count <-  length(unique(tw_points@data[tw_points@data$Date == i,"HiveID"]))
if (count < 3){
  remove_date <- c(remove_date, i )  
}
else{
  remove_hive <-  c(remove_hive, i)
}
  }

## remove_date contains the dates that only have two colonies and one of them only
## has a single dance. Let's remove data from these dates

print(remove_date)

tw_points <- tw_points[!(tw_points$Date %in% remove_date),]

## Now we have to remove the dances from the colonies with only a single
## dance on the dates with three colonies

## just double checking for overlap
remove_hive %in% remove_date

remove_hive_df <- tw_single[tw_single$date %in% remove_hive,]

## okay, so now we have a small df with the information need to 
## remove data from single colonies on the right dates

length(tw_points$HiveID) # we have this hear to confirm the number of dances
# removed in next step

for (i in remove_hive_df$date){
hive_to_remove <-  remove_hive_df[remove_hive_df$date == i, "hive"]
tw_points <- tw_points[!(tw_points$Date == i & tw_points$HiveID == hive_to_remove),]
}

length(tw_points$HiveID) # confirmed only 4 dances removed

## tw_points is now ready for the inter-dance distance and k-nearest neighbor
## analyses. However, for the k-mean cluster analysis, we want to have an idea 
## of how any dances there are on each individual day

tw_dance_count <- aggregate(list(dance_count = tw_points$DanceID), 
                            by = list(date = tw_points$Date), length)

range(tw_dance_count$dance_count)

## Dates have 4-74 dances

## Winchester

## Let's select only data from dates with dances from more than one colony.

w_agg <- aggregate(list(Hive = as.character(w_total_points$HiveID)),
                   by = list(Date = w_total_points$Date),
                   function(x) length(unique(x)))

w_agg <- w_agg[w_agg$Hive > 1,]
table(w_agg$Hive)

win_points <- 
  w_total_points[w_total_points$Date %in% unique(w_agg$Date),]

## Now we have to check for dates with a colonies that only 
## danced once. These dates will not allow for within versus 
## between comparisons, so they need to be removed.

win_count <- aggregate(DanceID ~ Date + HiveID, data = win_points,
                      FUN = function(x) length(unique(x)))
colnames(win_count) <- c("date", "hive", "count") 
win_single <- win_count[win_count$count == 1,]
print(win_single)

## There are two days with only one dance from one of the colonies.
## None of these dates have two colonies with only one dance.

## Now we need to determine if these dates contain data from three colonies or
## two colonies. The dates with only two colonies cannot be used. 

remove_date <- vector()
remove_hive <- vector()
for (i in win_single$date){
  count <-  length(unique(win_points@data[win_points@data$Date == i,"HiveID"]))
  if (count < 3){
    remove_date <- c(remove_date, i )  
  }
  else{
    remove_hive <-  c(remove_hive, i)
  }
}

## below we see that all of the dates with a colony with a single dance
## have dances from three colonies. Therefore, we don't have
## to remove all of the dances from this date because we can compare
## two of the colonies 

print(remove_date)

## We confirm that the other two dates just require removing date from 
## a specific colony

print(remove_hive)

## Let's find out which colonies need to be removed for these dates

win_remove_df <- win_single[win_single$date %in% remove_hive,]
print(win_remove_df)

## Now we remove the appropriate dances

length(win_points$DanceID) # check dance count first

win_points <- win_points[!((win_points$Date == "2019-06-18" &
                         win_points$HiveID == "wa") |
                            (win_points$Date == "2019-09-25" &
                           win_points$HiveID == "wb")),]

length(win_points$DanceID) # confirmed only two dances removed

## win_points is now ready for the inter-dance distance and k-nearest neighbor
## analyses. However, for the k-mean cluster analysis, we want to have an idea 
## of how any dances there are on each individual day

win_dance_count <- aggregate(list(dance_count = win_points$DanceID), 
                            by = list(date = win_points$Date), length)

range(win_dance_count$dance_count)

## Dates have 14-73 dances

## now we save the final analysis data as CSVs
## Our analysis will work with the spatial point data frames
## generated in this script, but we can keep these CSVs for
## sharing and examining the data. 

write.csv(bb_points, "./csv/bb_points.csv")
write.csv(tw_points, "./csv/tw_points.csv")
write.csv(win_points, "./csv/win_points.csv")

