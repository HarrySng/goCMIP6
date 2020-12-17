/*
Author: Harry Singh
Summary:
Script used for splitting CMIP6 data into grid-wise csv files
for parallel feeding into bias-correction algorithm.
*/

package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"reflect"
	"strconv"
	"sync"
	"time"

	"github.com/batchatco/go-native-netcdf/netcdf"
)

func main() {
	fname := os.Args[1]   // netcdf file name
	varName := os.Args[2] // variable name to extract

	// Track performance
	start := time.Now()

	readnetCDF(fname, varName) // primary function call

	elapsed := time.Since(start)
	fmt.Printf("The call took %v to run.\n", elapsed)
}

func readnetCDF(fname string, varName string) {
	nc, err := netcdf.Open(fname)
	handleError(err)
	defer nc.Close()

	vg, err := nc.GetVariable(varName)
	handleError(err)
	/*
		vg is a custom type composed of three entities
			Values		interface{}
			Dimensions	[]string
			Attributes	Another custom type
		The actual data is in Values
	*/

	vf := vg.Values
	/*
		This interface is composed of []float32 slices (or other type based on netcdf type)
		The number of slices in interface is equal to the 1st dimension of netcdf variable
		Each slice is further two dimensional (dim2*dim3 of netcdf file)
	*/

	vr := reflect.ValueOf(vf)
	/*
		This stores a reflected value of the interface which can be indexed and iterated over
	*/

	var wg sync.WaitGroup

	for i := 0; i < vr.Len(); i++ {
		wg.Add(1)
		f := "./dataFiles/v" + strconv.Itoa(i) + ".txt"
		go writeData(vr.Index(i).Interface().([][]float32), f, &wg)
		/*
			This will only work when you know the type is float 32
			See it with fmt.printf("T", vr.Index(0))
		*/
	}
	wg.Wait()
}

func writeData(d [][]float32, f string, wg *sync.WaitGroup) {

	file, err := os.Create(f)
	handleError(err)
	defer file.Close()

	w := csv.NewWriter(file)
	defer w.Flush()

	for _, value := range d {
		_, err := file.WriteString(fmt.Sprintf("%v\n", value))
		handleError(err)
	}
}

func handleError(err error) {
	if err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
	return
}