#!/bin/bash

# Directory structure
# ./
#	downscale.sh
#	rawnc/
#		getnc.py
#		sproket
#		target_grid
#	ncfiles/

# This script runs in parent directory

cd rawnc

for var in pr tasmax tasmin # 1st loop over variables
do # 1st loop do
for exp in historical ssp245 # 2nd loop over experiment
do # 2nd loop do
for mdl in CanESM5 # 3rd loop over model
do # 3rd loop do
python getnc.py $var $exp $mdl # This will create params.json
./sproket -config params.json # Downloads the netcdf file according to parameters in json file
while [ ! -s *.nc ] # While the file is download, its extension is nc_0, so wait till .nc exists
do
	: # Do nothing till file completely downloaded
done
mv *.nc ${var}_${exp}_${mdl}.nc # Rename the file
ncks -d lat,43.,54. -d lon,65.,95. ${var}_${exp}_${mdl}.nc -O ${var}_${exp}_${mdl}_subset.nc # Subset over study area
cdo remapbil,target_grid ${var}_${exp}_${mdl}_subset.nc ${var}_${exp}_${mdl}_d.nc # 
rm -f ${var}_${exp}_${mdl}_subset.nc ${var}_${exp}_${mdl}.nc # Cleanup
mv ${var}_${exp}_${mdl}_d.nc ../ncfiles/${var}_${exp}_${mdl}_d.nc
done
done
done
