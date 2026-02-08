###############################################################################
## 00 System Preparation                                                     ##
## This prepares the system, for example standardizing working directories,  ##
## installing of libraries, etc.                                             ##
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

## setup directory sub in the data folder structure
setwd(".")

## Install the required libraries
## googledrive allows access to the google drive API
## openxlsx will allow us to directly read XLSX files
## we need circular to deal with the angualr portion of the dance
## we need sp and raster to deal with spatial data

## Note that the rdgal package is no longer supported by CRAN.  Here is a link
## to the archived version that is relevant to the analysis 
## https://cran.r-project.org/src/contrib/Archive/rgdal/

defaultW <- getOption("warn") 
options(warn = -1)
required.packages <- c("openxlsx",
                       "sp",
                       "sf",
                       "circular",
                       "raster",
                       "plyr",
                       "stats",
                       "rgdal",
                       "RColorBrewer",
                       "rmarkdown")
currently.installed <- installed.packages()
for(i in required.packages){
    if(!(i %in% currently.installed[,"Package"])){
        install.packages(i, repos = "https://stat.ethz.ch/CRAN/")
    }
    library(i, character.only = TRUE)
}
options(warn = defaultW)


