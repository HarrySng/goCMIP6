# goCMIP6

## This is a research project repository for downscaling and bias-correction of CMIP6 data.

### The project is in still in its infancy. The eventual goal is to build a pipeline from dowscaling to bias-correction with minimal manual interference.

### The high-level steps of the pipeline will be as following:

1. Download CMIP6 products. There's already a useful binary for it here https://github.com/ESGF/sproket.

2. Subsetting the products over the study area using the [NCO library](http://nco.sourceforge.net/).

3. Downscaling the products to a target grid size using the [CDO library](https://code.mpimet.mpg.de/projects/cdo).

4. Distribute the products into grid-wise individual files using Goroutines for running parallel bias-correction procedures in R.

5. Bias-Correction of the products using the N-Dimensional Multivariate Bias Correction algorithm (MBC) package in R found [here](https://github.com/cran/MBC). More details about the algorithm can be found [here](https://doi.org/10.1007/s00382-017-3580-6).

6. Writing new netCDF with the bias-corrected data using Go.
 
