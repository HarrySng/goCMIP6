######################################################################################
#                    N-Dimensional Multivariate Bias Correction - Part 2             #
#                               Created By: Harry Singh                              #
#                       Team: Melika Rahimimovaghar, M Reza Najafi                   #
#                                 Date: Aug-01-2019                                  #
######################################################################################

# Objective
# N-Dimensional Multivariate Bias Correction (Cannon, 2018) of 8 CMIP5 GCMs (RCP 4.5 and 8.5) over Basins in Southern Canada

# Pre-processing
  # All GCMs are downscaled to match observations
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

print('STARTING NETCDF')

date_start <- '1950-01-01' # Start date of data
date_end <- '2100-12-31' # End date of data
missval <- -9999 # value for missing data
outfile <- paste(gcm_dir,'/MBC_',args[1],'_RCP',rcp,'.nc',sep='') # Name of netcdf file
chunk_size <- 5000 # Adjust according to RAM size

vars <- c('prAdjust','tasmaxAdjust','tasminAdjust')
units <- c('mm','C','C')

orig_id <- seq(1,39168,1) # Id of grids
na_ids <- which(unlist(readRDS('x.rds')) == 0) # NA grids were saved as a separate RDS for reference during preprocessing
grid_id <- orig_id[-na_ids]

# Create file names
file_names <- c(paste(gcm_dir,'/corr/grid_',seq(1,39168,1),'.rds',sep=''))

create_ncdf <- function(..) { # Parent wrapper function
  
  # Create time dimension
  # Time dimension will be number of days since 1900-01-01
  t <- as.numeric(seq(as.Date(date_start), as.Date(date_end),1) - as.Date('1900-01-01'))
  nc_time <- ncdim_def('time', "Days since 1900-01-01", t, unlim=T)
  print('Time Created')

  # Create space dimension
  lons <- seq(-108.96875,-92.03125,0.0625)
  lats <- seq(44.03125,52.96875,0.0625)
  space <- expand.grid(lon=lons, lat=lats) # All grids
  grid <- space
  grid$id <- seq(1,39168,1)
  # Find which grids should be NA because of expand grid
  pos_dim <- ncdim_def('position', units='count', vals=grid_id)
  lon_dim <- ncdim_def('lon', units= 'degrees_east', lons) 
  lat_dim <- ncdim_def('lat', units='degrees_north', lats)
  nc_pos_vars <- list(lon=lon_dim, lat=lat_dim, pos=pos_dim)
  dims <- list(nc_pos_vars$lon, nc_pos_vars$lat, nc_time) # This will be the dimension of the netcdf file
  
  # Create variables
  nvars <- length(vars)
  nc_vars <- list() # Place holder
  for (i in 1:nvars) { # Iterate over vars to create ncdf variables
    nc_vars[[i]] <- ncvar_def(vars[i], units[i], dims, missval=missval, compression=2)
  }
  
  nc <- nc_create(outfile, nc_vars) # Create the netcdf file
  nc_close(nc) # Close it (save it)
  print('File created')
  
  ## This will control the overall metadata - This is hardcoded - does not depend on variable definition done earlier
  add_attributes <- function(nc) {

    # Add the attributes to the variables
    # Metadata convention - Data Reference Syntax for bias-adjusted Coordinated Regional Downscaling Experiment (CORDEX)
    # Metadata reference - Nikulin, G., & Legutke, S. (2016).http://is-enes-data.github.io/CORDEX_adjust_drs.pdf
    ncdf.attributes <- list("0"=list( #global attributes

    NCProperties = "version=1|netcdflibversion=4.3.3.1|hdf5libversion=1.8.19",
    Conventions = "CF-1.6",
    title = paste('MBC Bias Corrected Data for ',args[1],' - RCP',args[2],sep=""),
    experiment = paste(args[1],' RCP ',args[2],sep=""),
    frequency = "day",
    contact = "hsing247@uwo.ca, mrahimim@uwo.ca, mnajafi7@uwo.ca",
    product = "bias-adjusted-output",
    creation_date = paste(Sys.time()),
    institution = "Department of Civil and Environmental Engineering, Western University",
    institute_id = "UWOCEE",
    bc_method = paste(
    				"Multivariate Bias Correction (MBCn)",  "Cannon 2018: Multivariate quantile mapping bias correction: 
    				an N-dimensional probability density function transform for climate model simulations of multiple variables", 
      				"Clim. Dynam. 50, 31â€“49, doi:10.1007/s00382-017-3580-6", 
      				sep="\n"),
    bc_method_id = "UWOCEE-MBCn",
    bc_observation = paste(
    				"Livneh et al. 2015 ",
  					"A spatially comprehensive, meteorological data set for Mexico, the U.S., and southern Canada (NCEI Accession 0129374). 
  					NOAA National Centers for Environmental Information",
  					"DOI: https://doi.org/10.7289/v5x34vf6", 
  					sep="\n"),
    bc_info = "UWOECC-MBCn-Livneh.et.al.-1950-2005",
    bc_period = "1950-2005",
	spatial_domain = 'Square grid over Red Basin',
    grid_resolution = '0.0625 degree grids',
    coordinate_system = 'WGS 1984'
    ),
    lon = list(
    			long_name = 'longitude',
                standard_name = 'longitude',
                units = 'degrees_east',
                axis = 'X'
    ),
    lat = list(
    			long_name = 'latitude',
                standard_name = 'latitude',
                units = 'degrees_north',
                axis = 'Y'
    ),
    time = list(
    			long_name = 'time',
    			standard_name = 'time',
    			bounds = "time_bnds",
    			units = "days since 1900-01-01 00:00:00",
                calendar = '365_day',
                axis = 'T'
    ),
    prAdjust = list(
    			long_name = 'Bias-Adjusted Precipitation',
                standard_name = 'precipitation_flux',
                missing_value = '-9999',
                units = 'mm',
                cell_method = 'time: mean (interval:24 hours)'
    ),
    tasmaxAdjust = list(
    			long_name = 'Bias-Adjusted Daily Maximum Near-Surface Air Temperature',
                standard_name = 'tasmax',
                units = 'C',
                missing_value = '-9999',
                cell_method = 'time: maximum (interval:24 hours)'
    ),
    tasminAdjust = list(
    			long_name = 'Bias-Adjusted Daily Minimum Near-Surface Air Temperature',
                standard_name = 'tasmin',
                units = 'C',
                missing_value = '-9999',
                cell_method = 'time: minimum (interval:24 hours)'
    )
  )

    # Add the attributes
    for (var.name in names(ncdf.attributes)) {
      for (att.name in names(ncdf.attributes[[var.name]])) {
        value <- ncdf.attributes[[c(var.name, att.name)]]
        if (is.character(value))
          mode <- attprec <- 'text'
        else
          attprec <- 'float'
        if (var.name == '0') var.name <- 0
        ncatt_put(nc, var.name, att.name, value, attprec, definemode=T)
      }
    }
    return(nc)
  }
  
  nc <- nc_open(outfile, write=T)
  nc_redef(nc)
  nc <- add_attributes(nc) # Adding attributes to file
  nc_enddef(nc)
  print('Atts added')
  
  read_data <- function(ff, nt, missval, vars) { # file is a single file name, nt is length of time dimension

    nadf <- data.frame(matrix(-9999, nrow = nt, ncol = 3)) # Missing value definition
    names(nadf) <- vars # needed for rbind later

    if (! file.exists(ff)) { # If grid not in basin, the filename would not exist
      stopifnot(!is.na(nt))
      return(nadf) # Return NA in that case
    } else {
      m1 <- readRDS(ff) # Read the file
    }
    class(m1) <- 'numeric'
    d <- data.frame(m1)
    names(d) <- vars # Name the columns
    return(d)
  }
  
  fill_lat_chunks <- function(nc, grid, chunk_size) { # Adds data to nc file in multiple lats at a time(chunk_size) 
    
    nt <- nc$dim$time$len # Define length of time dimension
    lats <- nc$dim$lat$vals # Lat dimension
    space.n <- nc$dim$lat$len * nc$dim$lon$len # Lon * Lat dimension
    
    lon_chunk_size <- floor(chunk_size / nc$dim$lat$len) # How many lons to iterate over
    files <- file_names
    lon_start <- 1
    while (lon_start <= nc$dim$lon$len) {
      
      lon_end <- min(lon_start + lon_chunk_size - 1, nc$dim$lon$len) # Go until length exceeds
      lons <- nc$dim$lon$vals[lon_start:lon_end] # Pull out these many lons
      all_points <- expand.grid(lons, lats) # square space
      colnames(all_points) <- c('lon','lat')
      common_grid <- inner_join(grid,all_points)
      i <- common_grid$id
      files <- file_names[i] # The number of files to be read in one iteration
      print(paste('<<<<<<<< Files to be read >>>>>>>>>>>>',length(files),sep=""))
      
      # Start a parallel job to load multiple files
      ncores <- detectCores() ; print('Cored detected')
      cl <- makeCluster(ncores) ; print('Cluster made')
      registerDoParallel(cl) ; print('Cluster registered')
      writeLines(c(""), "log.txt") # print iterations to a log file
      
      print('Starting foreach')
      data <- foreach(f = files, i = 1:length(files), .export = c('read_data')) %dopar% {
        sink("log.txt", append=TRUE)
        cat(paste("\n","Starting iteration",i,"\n")) # print iterations to a log file
        sink() #end diversion of output
        read_data(f,55152,-9999,c('prAdjust','tasmaxAdjust','tasminAdjust'))
      }
      stopCluster(cl)
      
      data <- abind(data, along=3) # bind the list along the third dimension
      names(dimnames(data)) <- c('time', 'var.name', 'space') # Name the dimensions
      ## Permute the array to (var.name, space, time)  so that we can do contiguous writes to the netcdf file (much faster)
      data <- aperm(data, c(2, 3, 1))
      
      gc() ## Clean up our mess
      
      for (var.name in dimnames(data)[['var.name']]) { # Pick up a single var
        print(paste("Writing", var.name, "values to netcdf"))
        n.to.write <- lon_end - lon_start + 1 # How many chunks to write
        rv <- try(ncvar_put(nc, var.name, data[var.name,,], start=c(lon_start,1,1), count=c(n.to.write,-1,-1)))
        if (inherits(rv, 'try-error')) # Debug errors
          browser()
      }
      rm(data)
      gc()
      lon_start <- lon_end + 1 # Repeat till end
    }
    
    nc_sync(nc)
    
    return(nc)
  }
  
  fill_lat_chunks(nc,grid,chunk_size) # Run the function
  nc_sync(nc) # Sync the data
  nc_close(nc) # Close the file
}
create_ncdf(..)
q()