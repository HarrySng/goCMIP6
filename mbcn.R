# Author: Harry Singh

# Load libraries
library(MBC)
library(lubridate)
library(tidyverse)
library(doParallel)

# Parameters
numLats <- 144
numLons <- 272

mbcnWrapper <- function(f, i) {
  readHistData <- function(f) {
    pr <- read.txt
  }


  mbc.n <- MBCn(o.m, h.m, f.m, # Observation, historical and future matrix
                iter = 100, # Iterations
                trace = 0.05, # Trace precipitation
                ratio.seq=c(T,F,F), # Prec is a ratio variable
                ties = 'first',
                jitter.factor=0.0001, # Jitter ties
                silent = T)
  return(mbc.n)

}	

fileNames <- c()
for (i in 1:numLats) {fileNames <- c(fileNames,paste(rep(i,numLats),"_",seq(1:numLons),".txt",sep=""))}

# Start a parallel job
ncores <- 20 ; print('Cores detected')
cl <- makeCluster(ncores) ; print('Cluster created')
registerDoParallel(cl) ; print('Cluster registered')
print(paste('Number of cores running is ', ncores, sep = "")) 
writeLines(c(""), "log.txt") # Print iterations to a log file
print('Starting foreach')

resls <- foreach(f = fileNames, i = 1:length(fileNames),
                 .packages=c('lubridate','MBC','tidyverse'), .export = c()) %dopar% {
                   sink("log.txt", append=TRUE)
                   cat(paste("\n","Starting iteration",i,"\n")) # Print iterations to a log file
                   sink() #end diversion of output
                   mbcnWrapper(f, i)
                 }
stopCluster(cl)

print('<<< bias correction done >>>')
q()
