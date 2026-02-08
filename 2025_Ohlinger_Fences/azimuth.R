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

# slightly modified from http://stackoverflow.com/questions/8708048/position-of-the-sun-given-time-of-day-latitude-and-longitude

sunPosition <- function(year, month, day, hour=12, min=0, sec=0, lat=50.863856, long=0.0836056) {
  reslt <- list(elevation = NA, azimuth = NA)
  if(!is.na(year) && !is.na(month) && !is.na(day) && !is.na(hour) && !is.na(min)){
      twopi <- 2 * pi 
      deg2rad <- pi / 180 

      # Get day of the year, e.g. Feb 1 = 32, Mar 1 = 61 on leap years 
      month.days <- c(0,31,28,31,30,31,30,31,31,30,31,30) 
      day <- day + cumsum(month.days)[month] 
      leapdays <- year %% 4 == 0 & (year %% 400 == 0 | year %% 100 != 0) & day >= 60 
      day[leapdays] <- day[leapdays] + 1 

      # Get Julian date - 2400000 
      hour <- hour + min / 60 + sec / 3600 # hour plus fraction 
      delta <- year - 1949 
      leap <- trunc(delta / 4) # former leapyears 
      jd <- 32916.5 + delta * 365 + leap + day + hour / 24 

      # The input to the Atronomer's almanach is the difference between 
      # the Julian date and JD 2451545.0 (noon, 1 January 2000) 
      time <- jd - 51545. 

      # Ecliptic coordinates 

      # Mean longitude 
      mnlong <- 280.460 + .9856474 * time 
      mnlong <- mnlong %% 360 
      mnlong[mnlong < 0] <- mnlong[mnlong < 0] + 360 

      # Mean anomaly 
      mnanom <- 357.528 + .9856003 * time 
      mnanom <- mnanom %% 360 
      mnanom[mnanom < 0] <- mnanom[mnanom < 0] + 360 
      mnanom <- mnanom * deg2rad 

      # Ecliptic longitude and obliquity of ecliptic 
      eclong <- mnlong + 1.915 * sin(mnanom) + 0.020 * sin(2 * mnanom) 
      eclong <- eclong %% 360 
      eclong[eclong < 0] <- eclong[eclong < 0] + 360 
      oblqec <- 23.429 - 0.0000004 * time 
      eclong <- eclong * deg2rad 
      oblqec <- oblqec * deg2rad 

      # Celestial coordinates 
      # Right ascension and declination 
      num <- cos(oblqec) * sin(eclong) 
      den <- cos(eclong) 
      ra <- atan(num / den) 
      ra[den < 0] <- ra[den < 0] + pi 
      ra[den >= 0 & num < 0] <- ra[den >= 0 & num < 0] + twopi 
      dec <- asin(sin(oblqec) * sin(eclong)) 

      # Local coordinates 
      # Greenwich mean sidereal time 
      gmst <- 6.697375 + .0657098242 * time + hour 
      gmst <- gmst %% 24 
      gmst[gmst < 0] <- gmst[gmst < 0] + 24. 

      # Local mean sidereal time 
      lmst <- gmst + long / 15. 
      lmst <- lmst %% 24.
      lmst[lmst < 0] <- lmst[lmst < 0] + 24. 
      lmst <- lmst * 15. * deg2rad 

      # Hour angle 
      ha <- lmst - ra 
      ha[ha < -pi] <- ha[ha < -pi] + twopi 
      ha[ha > pi] <- ha[ha > pi] - twopi 

      # Latitude to radians 
      lat <- lat * deg2rad 

      # Azimuth and elevation 
      el <- asin(sin(dec) * sin(lat) + cos(dec) * cos(lat) * cos(ha)) 
      az <- asin(-cos(dec) * sin(ha) / cos(el)) 
      elc <- asin(sin(dec) / sin(lat)) 
      az[el >= elc] <- pi - az[el >= elc] 
      az[el <= elc & ha > 0] <- az[el <= elc & ha > 0] + twopi 

      el <- el / deg2rad 
      az <- az / deg2rad 
      lat <- lat / deg2rad 

      reslt <- list(elevation=el, azimuth=az)
  }
  return(reslt)
} 
