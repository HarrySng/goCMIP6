######################################################################################
#                    N-Dimensional Multivariate Bias Correction - Part 1             #
#                               Created By: Harry Singh                              #
#                       Team: Melika Rahimimovaghar, M Reza Najafi                   #
#                                 Date: Aug-01-2019                                  #
######################################################################################

# Objective
# N-Dimensional Multivariate Bias Correction (Cannon, 2018) of 8 CMIP5 GCMs (RCP 4.5 and 8.5) over Basins in Southern Canada

# Pre-processing
	# All GCMs are downscaled to match observations
	# The data was extracted from NetCDF files and saved as gridwise lists in RDS files
	# See NetCDF attributes for details.

# All scripts are executed using a shell script to iterate over GCMs.

# Load libraries
library(MBC)
library(lubridate)
library(ncdf4) 
library(abind)
library(tidyverse)
library(doParallel)

# Arguments receeived from shell script
args = commandArgs(trailingOnly=TRUE)
gcm_dir <- paste('./',args[1],sep="")
rcp <- as.numeric(args[2])
print(gcm_dir) ; print(rcp)

# Load data and subset the first 20,000 grids
print('Reading obs')
obs_ls <- readRDS('obs_ls.rds')
print('Reading gcm hist')
gcm_hs <- readRDS(paste(gcm_dir,'/gcm_hist.rds',sep=""))
print('Reading gcm fut')
gcm_ft <- readRDS(paste(gcm_dir,'/gcm_',rcp,'.rds',sep=""))
print('Fut Data read')
gc()

# Parent function
bias_corr_wrapper <- function(oo, hh, ff, ii) {
  
  if (any(is.na(oo)) | any(is.na(hh)) | any(is.na(ff))) { # No NAs allowed in bias correction algorithm
    return(NA)
  }

  # Create date ranges
  dts1 <- seq(as.Date('1950-01-01'),as.Date('2005-12-31'),1)
  dts2 <- seq(as.Date('2006-01-01'),as.Date('2100-12-31'),1)

  # Split data into years
  annual_split <- function(m,dts) {
      m <- data.frame(m)
      if(length(m[,1]) < length(dts)) {dts <- dts[1:(length(m[,1]))]}
      m$date <- dts
      m <- split(m, year(m$date))
      return(m)
    }

    obs <- annual_split(oo, dts1) 
    hst <- annual_split(hh, dts1) 
    fut <- annual_split(ff, dts2)
  
  	# Function to iterate over years
    annual_wrapper <- function(o.y,h.y,f.y) { # Each year of

      # Split into months
      o.y <- split(o.y, month(o.y$date))
      h.y <- split(h.y, month(h.y$date))
      f.y <- split(f.y, month(f.y$date))
      
      # Function to iterate over months
      monthly_wrapper <- function(o.m, h.m, f.m) { # Iterate over o.y, m.y
        o.m <- as.matrix(o.m[,1:3])
        h.m <- as.matrix(h.m[,1:3])
        f.m <- as.matrix(f.m[,1:3])        
    
        mbc.n <- MBCn(o.m, h.m, f.m, # Observation, historical and future matrix
                      iter = 100, # Iterations
                      trace = 0.05, # Trace precipitation
                      ratio.seq=c(T,F,F), # Prec is a ratio variable
                      ties = 'first',
                      jitter.factor=0.0001, # Jitter ties
                      silent = T)
        return(mbc.n)
      }

      # Correct monthly
      corrected_monthly <- lapply(1:12, function(i) monthly_wrapper(o.y[[i]], h.y[[i]], f.y[[i]]))

      # Bind back to annual
      cordata <- list()
      for (i in 1:12) { 
        cordata[[i]] <- corrected_monthly[[i]][[2]]
      }     
      cordata <- do.call(rbind, cordata)

      return(cordata)
    }
    
    # Correct annual
    corrected_annual1 <- lapply(1:length(obs), function(i) annual_wrapper(obs[[i]], hst[[i]], fut[[i]]))
    corrected_annual2 <- lapply((length(obs)+1):length(fut), function(i) annual_wrapper(obs[[i-length(obs)]], hst[[i-length(obs)]], fut[[i]]))

    # Bind back to series
    cordata <- list()
    for (i in 1:length(obs)) { 
      cordata[[i]] <- corrected_annual1[[i]][[2]]
    }     
    for(i in 1:length(corrected_annual2)) {
    	cordata[[length(cordata)+1]] <- corrected_annual2[[i]][[2]]
    }
    cordata <- do.call(rbind, cordata)

    saveRDS(cordata,paste('./',gcm_dir,'/corr/grid_',ii,'.rds',sep=""),compress = F) # Save corrected data of each grid.
}	

# Start a parallel job
ncores <- 30 ; print('Cores detected')
cl <- makeCluster(ncores) ; print('Cluster made')
registerDoParallel(cl) ; print('Cluster registered')
print(paste('Number of cores running is ', ncores, sep = "")) 
writeLines(c(""), "log.txt") # Print iterations to a log file
print('Starting foreach')

resls <- foreach(o.o = obs_ls, h.h = gcm_hs, f.f = gcm_ft, i.i = 1:length(obs_ls),
                 .packages=c('lubridate','MBC','tidyverse'), .export = c('gcm_dir')) %dopar% {
                   sink("log.txt", append=TRUE)
                   cat(paste("\n","Starting iteration",i.i,"\n")) # Print iterations to a log file
                   sink() #end diversion of output
                   bias_corr_wrapper(o.o, h.h, f.f, i.i)
                 }
stopCluster(cl)

print('<<< bias correction done >>>')
q()
