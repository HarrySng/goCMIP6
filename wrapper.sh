#!/bin/bash
 
cd rawnc

declare -a model=("CanESM5" "NorESM2-LM" "IPSL-CM6A-LR" "EC-Earth3" "ACCESS-CM2")
declare -a experiment=("historical" "ssp245")
declare -a variable=("pr" "tasmax" "tasmin")

for mdl in "${model[@]}"; do
	for exp in "${experiment[@]}"; do
		for var in "${variable[@]}"; do
			python getnc.py $var $exp $mdl
			./sproket -config params.json # a1
			while [ -e *.part ]; do # a2
				:
			done
		done
	done
done

echo "All files downloaded."

mkdir -p ../ncfiles

# All files have been downloaded by the above loop
# Now subset and downscale and move to another directory

for file in *.nc_0; do # Some files are named .nc_0, change them to .nc
	fname=$(echo "$file" | rev | cut -d'.' -f 2- | rev)
	mv ${file} ${fname}.nc
done

for file in *.nc; do
	echo "Downscaling $file"
	fname=$(echo "$file" | rev | cut -d'.' -f 2- | rev)
	ncks -d lat,43.,54. -d lon,65.,95. $file -O ${fname}_subset.nc
	rm -f $file
	cdo remapbil,target_grid ${fname}_subset.nc ${fname}_d.nc
	ncpdq -a lat,lon,time ${fname}_d.nc ${fname}.nc # Flip dims to lat,lon,time
	rm ${fname}_subset.nc ${fname}_d.nc # Cleanup
	mv ${fname}.nc ../ncfiles/${fname}.nc
done

echo "All files downscaled and moved to ncfiles/"

cd ../ncfiles/

for mdl in "${model[@]}"; do
	for exp in "${experiment[@]}"; do
		mkdir -p "./${mdl}_${exp}"
		go run ../gomat.go $mdl $exp
	done
done


# var=$(echo "$file" | cut -d'_' -f 1 | rev | cut -d'.' -f 1 | rev) # Extract variable name


# a1
	# sprocket will start downloading 1 or multiple files
	# depending on whether that scenario has just 1 nc file
	# or it is split into multiple nc files.

# a2
	# When files are being downloaded, they are named as 
	# .part. Once the download is complete, they are named
	# to .nc
	# So, this command checks whether any .part file is 
	# remaining in the directory. This way the next
	# iteration only starts when all files from one
	# iteration have been fulle downloaded.