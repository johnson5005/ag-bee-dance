###############################################################################
## 01 Dance Data Preparation                                                 ##
## This script imports the data and makes                                    ##
## it ready for use in other scripts                                         ##
## (need to run 00_system_Prep.R before this)                                ##
## Author: Roger Schürch and Bradley Ohlinger                                ##
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

# Before running this script, set your working directory to the 
# foraging_cluster_analysis folder. 

# First we create a data frame containing hive information.
hive_data <- data.frame(hive = c("ba", "bb", "bc", "ta", "tb", "tc", "wa", "wb", "wc"),
                        longitude = c(-80.489351,-80.489351,-80.489351,
                                      -76.73277778, -76.73277778, -76.73277778,
                                      -78.284492, -78.284492, -78.284492),
                        latitude = c(37.211479, 37.211479, 37.211479,
                                     36.66447222, 36.66447222, 36.66447222,
                                     39.113489, 39.113489, 39.113489),
                        crs.string = c(rep("+init=epsg:32147", 6), rep("+init=epsg:32146", 3)),
                        stringsAsFactors = FALSE)
hive_data_sp <- SpatialPointsDataFrame(hive_data[,c("longitude",
                                                    "latitude")],
                                       hive_data,
                                       proj4string = CRS("+init=epsg:4326"))
## calculate eastings and northings
hive_data_sp_south <- spTransform(hive_data_sp, CRS("+init=epsg:32147"))
hive_data_sp_north <- spTransform(hive_data_sp, CRS("+init=epsg:32146"))
eastings_northings <- rbind(hive_data_sp_south@coords[1:6,], hive_data_sp_north@coords[7:9,])

data <- read.csv("./csv/dance_data.csv")

## data aggregation
data$TotalAngle <- circular(data$TotalAngle,
                            template = "geographics",
                            rotation = "clock", units = "degrees")
data_agg <- aggregate(list(Duration = data$Duration, TotalAngle = data$TotalAngle),
                      by = list(DanceID = data$DanceID,
                                HiveID = data$HiveID,
                                Date = data$Date),
                                mean)

data_agg2 <- aggregate(list(Time = data$Time1),
                       by = list(DanceID = data$DanceID),
                       head, 1)
data_agg <- merge(data_agg, data_agg2, by = "DanceID")
data_agg <- data_agg[!is.na(data_agg$Date),]
data_agg$Date <- as.Date(data_agg$Date, format = "%m/%d/%Y")
data_agg$dt <- NA
for(i in 1:nrow(data_agg)){
    try(data_agg$dt[i] <- convertToDateTime(data_agg$Time[i], origin = data_agg$Date[i]))
}
data_agg$dt <- as.POSIXct(data_agg$dt, origin = "1970-01-01")
data_agg <- data_agg[!is.na(data_agg$dt),]

data_agg$TotalAngle <- circular(data_agg$TotalAngle,
                                template = "geographics",
                                rotation = "clock", units = "degrees")
hive_data <- cbind(hive_data, eastings_northings)
names(hive_data) <- c("HiveID", "longitude", "latitude", "crs.string", "easting", "northing")
data_agg <- merge(data_agg, hive_data, all.x = TRUE)




## calculate azimuth with function from script: FIX LATITUDE AND LONGITUDE!!!
source("./scripts/azimuth.R")

## sometimes the video recorder was set 12 hours fast, we need to fix that
## ALL THIS NEEDS TO BE FIXED IN THE DATA!!!!
data_agg$dt <- as.POSIXlt(data_agg$dt)
data_agg$dt$hour <- ifelse(data_agg$dt$hour > 17, data_agg$dt$hour - 12, data_agg$dt$hour)
data_agg$dt$hour <- ifelse(data_agg$dt$hour < 8, data_agg$dt$hour + 12, data_agg$dt$hour)
data_agg <- data_agg[!is.na(data_agg$longitude),]

data_agg$azimuth <- mapply(function(dt, lat, lon) {
  pos <- sunPosition(year = as.numeric(format(dt, "%Y")),
                     month = as.numeric(format(dt, "%m")),
                     day = as.numeric(format(dt, "%d")),
                     hour = as.numeric(format(dt, "%H")) + 4,
                     min = as.numeric(format(dt, "%M")),
                     sec = 0,
                     lat = lat, long = lon)
  pos$azimuth
}, dt = data_agg$dt, lat = data_agg$latitude, lon = data_agg$longitude)


## calculate bee flight heading
data_agg$heading <- data_agg$TotalAngle + data_agg$azimuth
data_agg$heading.rad <- conversion.circular(data_agg$heading,
                                            units = "radian")

write.csv(data_agg, "./csv/dance_agg_data.csv")

