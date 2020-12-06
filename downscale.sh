#!/bin/bash


# Download wget scripts from https://esgf-node.llnl.gov/search/cmip6/
#Create the following directory structure
##########################################
# parent/                                #
#        downscale.sh                    #
#        target_grid                     #
#        shellFiles/                     #
#                  all wget scripts      #
##########################################
# chmod +x to all wget scripts to make them executable

for file in ./shellFiles/* # For each wget script
do
  sh $file -s # execute the script which downloads the nc file in parent/ directory
done

for file in *.nc # For each netcdf file (global raw file)
do
  var=$(echo $file | cut -d'_' -f 1-4) # Extract a substring of its name to make it easier to interpret
  mv $file ${var}.nc # Rename the file
done

for file in *.nc # For each renamed file (still global raw file)
do
  var=$(echo $file | cut -d'.' -f 1) # Extract the substring name again, will use later
  ncks -d lat,43.,54. -d lon,65.,95. $file -O ${var}_subset.nc # Clip the file to a bounding box bigger than observation area
  rm -f $file # Clean up
  cdo remapbil,target_grid ${var}_subset.nc $file # Downscale the file using bilinear interpolation
  rm -f ${var}_subset.nc # Clean up
done
