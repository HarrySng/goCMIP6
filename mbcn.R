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

obsFiles <- list.files(path = obs, full.names=T)
histFiles <- list.files(path = gcmHist, full.names=T)
futFiles <- list.files(path = gcmFut, full.names=T)
# Each of these is a vector of files names = no. of grids

mbcnWrapper <- function(o.f, h.f, f.f, i.i) {

	

 	mbc.n <- MBCn(o.m, h.m, f.m,
 		iter = 100,
 		trace = 0.05,
 		ratio.seq=c(T,F,F),
 		ties = 'first',
 		jitter.factor=0.0001,
 		silent = T)
 	
  	return(mbc.n)

}	


# Start a parallel job
ncores <- 30 ; print('Cores detected')
cl <- makeCluster(ncores) ; print('Cluster created')
registerDoParallel(cl) ; print('Cluster registered')
print(paste('Number of cores running is ', ncores, sep = "")) 
writeLines(c(""), "log.txt") # Print iterations to a log file
print('Starting foreach')

resls <- foreach(o.f = obsFiles, h.f = histFiles, f.f = futFiles, i.i = 1:length(fileNames),
                 .packages=c('lubridate','MBC','tidyverse'), .export = c()) %dopar% {
                   sink("log.txt", append=TRUE)
                   cat(paste("\n","Starting iteration",i.i,"\n")) # Print iterations to a log file
                   sink() #end diversion of output
                   mbcnWrapper(o.f, h.f, f.f, i.i)
                 }
stopCluster(cl)

print('<<< bias correction done >>>')
q()
