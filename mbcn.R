# Author: Harry Singh

# Load libraries
library(MBC)
library(lubridate)
library(tidyverse)
library(doParallel)

# Parameters
args = commandArgs(trailingOnly=TRUE)
gcmHist = paste("./",args[1],"historical/",sep="")
gcmFut = paste("./",args[1],"ssp245/",sep="")
ncores <- 30 ; print('Cores detected')
prd <- 10950 # Number of historical period days (365*30)
iter <- 30
rotSeq <- replicate(iter, list(rot.random(3)))
# Both periods homoeginzed to 365 day calendar by removing leap days


#############################################

obsFiles <- list.files(path = obs, full.names=T)
histFiles <- list.files(path = gcmHist, full.names=T)
futFiles <- list.files(path = gcmFut, full.names=T)
# Each of these is a vector of files names = no. of grids

mbcnWrapper <- function(o.f, h.f, f.f, i.i) {
   
   readData <- function(f) {
      d <- read.csv(f, header = F)
      d[,1] <- d[,1]*86400 # pr to mm/day
      d[,2] <- d[,2]-273.15 # tmax/tmin to deg.C
      d[,3] <- d[,3]-273.15
      return(d)
   }
   dls <- lapply(list(o.f, h.f, f.f), readData)
   
   windows <- floor(dim(dls[[3]])[1]/(prd/3)) # Num of window iterations
   
   ww <- c(1) # Window index
   for (i in 2:(windows+1)) {
      ww[i] <- (365*(i-1)*10)+1
   }
   
   windowWrapper <- function(w) {
      o.w <- dls[[1]]
      h.w <- dls[[2]]
      f.w <- dls[[3]][w:(w+(prd-1)),]
      mbc.n <- MBCn(o.w, h.w, f.w,
                    iter = iter,
                    trace = 0.05,
                    ratio.seq=c(T,F,F),
                    rot.seq=rotSeq,
                    ties = 'first',
                    jitter.factor=0.0001,
                    silent = T)
      return(list(mbc.n$mhat.c, mbc.n$mhat.p))
   }

   rls <- lapply(ww, windowWrapper)
   
   # Now subset projected results
 	subsetProjections <- function(i) {
 	   p <- rls[[i]][[2]]
 	   if (i == 1) {
 	      return (p[1:(prd/3),]) # First 10 years from first window
 	   } else if (i == windows) {
 	      return (p[ww[windows]:dim(p)[1],]) # Last 10 years from last window7
 	   } else {
 	      return (p[((prd/1.5)+1):prd]) # Middle 10 years from middle windows
 	   }
 	}
 	srls <- lapply(1:(windows+1), subsetProjections)
 	
 	srls <- do.call(lapply(rbind, srls)) # Join lists vertically into one big mat
   
 	rmat <- rbind(rls[[1]][[1]], srls) # Join hisotrical and projection into one final result matrix
 	
   write.csv(rmat, paste("./bcdata/",word(o.f,3,3,"/"),".csv",sep=""), row.names = F)

}	


# Start a parallel job
cl <- makeCluster(ncores) ; print('Cluster created')
registerDoParallel(cl) ; print('Cluster registered')
print(paste('Number of cores running is ', ncores, sep = "")) 
writeLines(c(""), "log.txt") # Print iterations to a log file
print('Starting foreach')

resls <- foreach(o.f = obsFiles, h.f = histFiles, f.f = futFiles, i.i = 1:length(obsFiles),
                 .packages=c('lubridate','MBC','tidyverse'), .export = c("prd", "iter", "rotSeq")) %dopar% {
                   sink("log.txt", append=TRUE)
                   cat(paste("\n","Starting iteration",i.i,"\n")) # Print iterations to a log file
                   sink() #end diversion of output
                   mbcnWrapper(o.f, h.f, f.f, i.i)
                 }
stopCluster(cl)

print('<<< bias correction done >>>')
q()
