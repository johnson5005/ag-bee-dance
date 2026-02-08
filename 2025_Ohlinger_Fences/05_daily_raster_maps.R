###############################################################################
## 05 Daily Raster Maps                                                      ##
## This script generates daily foraging probability raster maps for each day ##
## in the study.                                                             ##
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

# Honey bee foraging probability maps for spatial foraging study.

## Points
current_site <- "blacksburg" # specifies field site
current_hives <- paste0(substring(current_site, 1, 1), c("a", "b", "c")) # specifies hives

## Now let's read in some data. This is data set was prepared via 01_dance_data_prep
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
# total_points$Distance <- sqrt((total_points$easting - mean_hive_easting)^2 +
#                                 (total_points$northing - mean_hive_northing)^2)


# here we merge data_agg to total_points to associate the relevant date and hive information
total_points <- 
  merge(total_points, data_agg[,c("DanceID", "HiveID", "dt")], by = "DanceID")
total_points$Date <- format(total_points$dt, "%Y-%m-%d")
total_points$HiveID <- as.factor(total_points$HiveID)

# Rasters
# Now let's set up our raster template, several of these values 

distance_to_hives <- 2250
grid_cell_size <- 25

no_cells <- 2 * distance_to_hives / grid_cell_size


coord_panel <- data.frame(cbind(easting = c(mean_hive_easting,
                                            mean_hive_easting - distance_to_hives,
                                            mean_hive_easting + distance_to_hives),
                                northing = c(mean_hive_northing,
                                             mean_hive_northing - distance_to_hives,
                                             mean_hive_northing + distance_to_hives)))
sp::coordinates(coord_panel) <- c("easting", "northing")
proj4string(coord_panel) = CRS(crs_string)
num_coord_panel <- as.data.frame(coord_panel)

## Here we create a raster, assign it's extent and it's spatial projection
temp_rast <- raster(ncols = no_cells, nrows = no_cells)
extent(temp_rast) <- extent(c(num_coord_panel[2:3,1], num_coord_panel[2:3,2])) 
proj4string(temp_rast) = CRS(crs_string)

# Here we create a date frame with the colors for each hive in the raster


hive_colors <- data.frame(HiveID = c("ba", "bb", "bc"),
                          color = c("red", "blue", "yellow"))

# Shapefiles
# Here we load the landscape shapefile for the PFRC

land <- readOGR(dsn = "./shapefiles",
                  layer = "study_area_2250km")



# Now that we have all the data that we need, let's write a function for 
# plotting the foraging probability rasters

# Here we write a function for rasterizing simulated points

# First we specify final.n
final.n <- 1000

calcProbRaster <- function(simulated.points, raster.template){
  reslt <- raster.template
  for(i in 1:length(unique(simulated.points$DanceID))){
    point.select <- simulated.points$DanceID == unique(simulated.points$DanceID)[i]
    current.points <- simulated.points[point.select, c("easting", "northing")]
    coordinates(current.points) <- c("easting", "northing")
    proj4string(current.points) <- CRS(crs(raster.template)@projargs) # which
    current.raster <- rasterize(current.points,
                                reslt,
                                fun = "count", background = 0) / final.n
    if(i <= 1){
      reslt <- current.raster
    }else{
      reslt <- 1 - (1 - reslt) * (1 - current.raster)
    }
  }
  return(reslt)
}


# Here we create a loop that plots foraging on each day for each hive

for (date in unique(total_points$Date)){
  
  date_data <- total_points[total_points$Date == date,] 
  jpeg(paste0("./", "images/",date, ".jpeg"))
  plot(land)
  
  for (hive in unique(date_data$HiveID)){
    
    hive_data <- date_data[date_data$HiveID == hive,]
    hive_raster <- calcProbRaster(hive_data, temp_rast)
    col.fun <- 
      colorRampPalette(colors = c(adjustcolor(hive_colors[hive_colors$HiveID == hive, "color"], alpha.f = 0),
                                  adjustcolor(hive_colors[hive_colors$HiveID == hive, "color"], alpha.f = 0.75)),
                       alpha = TRUE)
    my.palette <- col.fun(100)
    
   
     plot(hive_raster, col =  my.palette, legend = FALSE, add = TRUE)
    
    if (hive == tail(unique(date_data$HiveID),1)){
      dev.off()
}}}





