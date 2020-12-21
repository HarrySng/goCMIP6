# goCMIP6

## A research project repository for downscaling and bias-correction of CMIP6 data.

<br/><br/>

# Pre-requisites


## Install gcc

```bash
sudo dnf install gcc
gcc --version
```

## Install NCO

```zsh
# For RedHat/Fedora based distros
# This particular build was done in CentOS 8.3.2011

# Install nco (which installs netcdf, hdf5 and some other packages as dependencies)
sudo dnf install epel-release

# Need to enable powertools for some dependencies of nco
sudo dnf -y install dnf-plugins-core
sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf config-manager --set-enabled powertools

# Install
sudo dnf install nco

# Need to install netcdf-devel separately
sudo dnf install netcdf-devel

# Check that netcdf has NetCDF-4/HDF5 enabled
nc-config --has-nc4
```

## Install CDO

```zsh
# Install cdo
# Download the latest tar package from here https://code.mpimet.mpg.de/projects/cdo/files
tar -xzvf cdo-*
cd cdo-*
./configure --with-netcdf=/usr --with-hdf5=/usr # Build with NetCDF4 support
sudo make
sudo make install

cdo --version

# The downloading of NetCDF files from ESGF will be handled through an existing binary here https://github.com/ESGF/sproket

```

# Workflow

## Subsetting and Downscaling NetCDF files

```zsh
# wrapper.sh is a wrapper job that triggers everything else
# Three parameters can be customized in the job

for mdl in CanESM5 NorESM2-LM IPSL-CM6A-LR EC-Earth3 ACCESS-CM2; do # Add/remove GCMs here (source_id in ESGF)
	for exp in historical ssp245; do # Add/remove experiments here (experiment_id in ESGF)
		for var in pr tasmax tasmin; do # Add/remove variables here (variable_id in ESGF)
			python getnc.py $var $exp $mdl
			./sproket -config params.json # a1
			while [ ! -e *.part]; do # a2
				:
			done
		done
	done
done

```

## Splitting NetCDF

```go
// After files have been downloaded, subsetted, downscaled and moved to ncfiles/ directory
// Call goncdf.go to split into grid-wise independent files using Goroutines to feed into bias-correction process
// Here's the primary chunk of code that does the splitting

	for i := 0; i < vr.Len(); i++ { // Loop across 1st dim (lat)
		for j := 0; j < len(vr.Index(i).Interface().([][]float32)); j++ { // Loop across 2nd dim (lon)
			wg.Add(1) // Send a signal to the workgroup that an iteration has initiated
			f := "./dataFiles/v" + strconv.Itoa(i) + "_" + strconv.Itoa(j) + ".txt"
			go writeData(sem, vr.Index(i).Interface().([][]float32)[j], f, &wg) // Write 3rd dim to file (time)
		}
		wg.Wait() // Stop "main" from exiting till all goroutines finish
	}
```

## Bias-correction and Creation of new NetCDF files

```R
# Bias-correction done in mbcn.R
# Grid-wise data is fed into MBC algorithm in R iteratively
# Bias-correction is done using moving windows of 30-years
# Bias-corrected grids replace the raw grid data to save disk space

 mbc.n <- MBCn(o.m, h.m, f.m, # Observation, historical and future matrix
               iter = 100, # Iterations
              trace = 0.05, # Trace precipitation
              ratio.seq=c(T,F,F), # Prec is a ratio variable
              ties = 'first',
              jitter.factor=0.0001, # Jitter ties
              silent = T)
return(mbc.n)

# New NetCDF files created in createnc.R
```

# To Do

1. Remove annual-monthly split form mbcn.R
2. Add moving-windows to mbcn.R
3. Write a parent wrapper job to execute all scripts.
4. Build email alerts within the job to update progress.

<br/>

## References

1. [Sproket binary](https://github.com/ESGF/sproket)

2. [NCO library](http://nco.sourceforge.net/)

3. [CDO library](https://code.mpimet.mpg.de/projects/cdo)

4. [MBC package](https://github.com/cran/MBC) and corresponding [Research Article](https://doi.org/10.1007/s00382-017-3580-6)

 
