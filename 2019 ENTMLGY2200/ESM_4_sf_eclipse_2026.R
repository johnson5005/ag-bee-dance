######## Updated for modern R spatial stack (sf and terra)
######## Original by Douglas Sponsler and Reed Johnson (johnson.5005@osu.edu).

# Load necessary packages
library('circular')    # for circular stats
library('rjags')       # interface with JAGS
library('sf')          # modern replacement for sp and rgdal
library('terra')       # modern replacement for raster
library('png')         # to save figures
library('googlesheets4') # updated from googlesheets
library('magrittr')    # Pipes
library('oce')         # Calculation of azimuth

## Clear everything
rm(list=ls())

## Set local working directory
setwd("./2019 ENTMLGY2200") 
dir.create("data", showWarnings = FALSE)

## Import dance data file
# Note: googlesheets4 uses read_sheet or gs4_download
# gs4_auth() # You may need to authenticate
waggleData <- read_sheet("1kUu7DLIM1LaOsXZAV3K6hwke2TilBNdlBG5lYIMpd84")
waggleData <- subset(waggleData, is.na(waggleData$flag))

## Fix dates/times and calculate azimuth
waggleData$date <- paste(waggleData$year, sprintf("%02d", waggleData$month), sprintf("%02d", waggleData$day), sep="-")
waggleData$time <- paste(sprintf("%02d", waggleData$hour), sprintf("%02d", waggleData$min), sep=":")
waggleData$dateTime <- as.POSIXct(strptime(paste(waggleData$date, waggleData$time, sep=" "), "%Y-%m-%d %H:%M"), tz="US/Eastern")
attr(waggleData$dateTime, "tzone") <- "UTC"
waggleData$azimuth <- sunAngle(waggleData$dateTime, waggleData$lon, waggleData$lat, useRefraction=TRUE)$azimuth

## Calculate heading in radians
waggleData[is.na(waggleData$skew),]$skew <- 0
waggleData$heading.degrees <- (((waggleData$mean_angle - waggleData$skew + waggleData$azimuth) + 90) %% 360)
waggleData$heading.radians <- (waggleData$heading.degrees * pi) / 180

# Calibration Data
calibDataAgg <- read.csv("ESM_5.csv", row.names = 1)
calibDataAgg$heading <- circular(calibDataAgg$heading, type = "angle", unit = "radian", rotation = "clock", zero = pi/2)
waggleData$heading <- circular(waggleData$heading.radians, type = "angle", unit = "radian", rotation = "clock", zero = pi/2)

finalSampleSize <- 1000
thinning <- 100
noJagsSamples <- thinning * finalSampleSize

## Spatial Setup (UTM 17N - EPSG:26917)
hiveEasting <- 422365.52
hiveNorthing <- 4514220.68
distanceToHives <- 10000
gridCellSize <- 25
noCells <- 2 * distanceToHives / gridCellSize

# Define the extent for terra
# xmin, xmax, ymin, ymax
ext_vals <- c(hiveEasting - distanceToHives, hiveEasting + distanceToHives, 
              hiveNorthing - distanceToHives, hiveNorthing + distanceToHives)

# Create a template raster using terra
temp.rast <- rast(xmin=ext_vals[1], xmax=ext_vals[2], 
                  ymin=ext_vals[3], ymax=ext_vals[4], 
                  res=gridCellSize, crs="EPSG:26917")
values(temp.rast) <- 0
total.temp.rast <- temp.rast

# JAGS Setup
calibDataAggBees <- calibDataAgg[!is.na(calibDataAgg$bee.id),]
N1 <- length(calibDataAggBees$duration)
x <- calibDataAggBees$distance
y <- calibDataAggBees$duration
K <- length(unique(calibDataAggBees$bee.id))
bee <- factor(calibDataAggBees$bee.id)

# Process loop
waggleCollected <- waggleData
waggleCollected$dateColor <- paste(waggleCollected$date)

for (j in unique(waggleCollected$dateColor)) {
  waggleDataDate <- waggleCollected[waggleCollected$dateColor == j,]
  
  for(i in 1:length(waggleDataDate$dancer.id)){
    cat(paste(i, "of", length(waggleDataDate$dancer.id), "\n"))
    tempData <- waggleDataDate[i,]
    
    N2 <- length(tempData$mean_duration.sec)
    x2 <- rep(NA, length(tempData$mean_duration.sec))
    y2 <- tempData$mean_duration.sec
    
    jags <- jags.model('ESM_3.jag', 
                       data = list('x' = x, 'y' = y, 'N1' = N1, 'K' = K, 'bee' = bee, 'N2' = N2, 'x2' = x2, 'y2' = y2),
                       n.chains = 1, n.adapt = 100)
    update(jags, 100000)
    samples <- coda.samples(jags, c('x2'), noJagsSamples, thin = thinning)
    sim.distances <- samples[,'x2'][[1]]
    
    sim.heading <- rvonmises(finalSampleSize, mu = tempData$heading, 
                             kappa = 24.9, control.circular = list("radians"))
    
    rel.dance.easting <- as.numeric(hiveEasting + cos(-(sim.heading - pi/2)) * sim.distances)
    rel.dance.northing <- as.numeric(hiveNorthing + sin(-(sim.heading - pi/2)) * sim.distances)
    
    # Create sf points
    temp_df <- data.frame(id = rep(tempData$id, length(rel.dance.easting)),
                          easting = rel.dance.easting,
                          northing = rel.dance.northing)
    temp_sf <- st_as_sf(temp_df, coords = c("easting", "northing"), crs = 26917)
    
    # Write CSV
    write.csv(temp_df, paste0("data/sim.dance_", tempData$id, ".csv"), row.names = FALSE)
    
    # Rasterize using terra
    # fun="count" followed by division by sample size
    dance_rast <- rasterize(temp_sf, temp.rast, fun = "count", background = 0) / finalSampleSize
    
    # Update total probability visited
    if(i <= 1){
      total.temp.rast <- dance_rast
    } else {
      total.temp.rast <- 1 - (1 - total.temp.rast) * (1 - dance_rast)
    }
  }
  
  # Save the final raster for this dateColor
  writeRaster(total.temp.rast, filename = paste0("data/Wooster_Eclipse_", j, ".tif"), overwrite = TRUE)
}

### PLOTTING
myAlpha <- c(0, seq(0.005, 0.5, 0.005) + 0.3)
myCols <- rev(rainbow(100, alpha = rev(myAlpha)))

# terra uses a simple plot() command
plot(total.temp.rast, col = myCols, main = paste("Dance Heatmap:", j))
points(hiveEasting, hiveNorthing, pch = 20, col = "black", cex = 1)