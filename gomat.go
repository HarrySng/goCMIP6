/*
Author: Harry Singh
Summary:
Create bias-correction ready matrices from netcdf files to feed into R MBCn algorithm.

High-level workflow
	1. Open all var.nc files from one scenario
	2. Write txt files to disk containing 3 columns (pr, tasmax, tasmin) along time dimension
	3. Repeat for historical and ssp245and once for obs
*/

package main

import (
	"encoding/csv"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/batchatco/go-native-netcdf/netcdf"
)

func main() {

	start := time.Now()

	if len(os.Args) != 2 {
		err := errors.New("Please provide two command line arguments (ModelName ExperimentName). Example: CanESM5 ssp245")
		handleError(err)
	}

	mdl := os.Args[1] // GCM model name
	exp := os.Args[2] // Experiment name

	// Modifying directories is handled in shell script
	files, _ := filepath.Glob("*" + mdl + "_" + exp + "*") // Find files in current directory matching pattern

	// Some repetition to avoid short for loops
	d0 := getDataSlice(files[0]) // []interface{} returned by func
	d1 := getDataSlice(files[1])
	d2 := getDataSlice(files[2])

	var wg sync.WaitGroup // Start a waitgroup to ensure all goroutines finish before "main" exits
	sem := make(chan int, 1000)
	/*
		Channels are used to limit the number of concurrent goroutines.
		Here, a channel of specific size is initiated (1000) which
		ensures that only 1000 goroutines can run at a time.
		This ensures memory issues as well as limits on concurrent
		number of files open at one time on the OS.
		For every iteration, an integer is entered into this channel.
		The channel keeps accepting integers till it reaches its size limit.
		Then it stops accepting anymore insertions, thus ensuring the next
		iteration does not execute.
		At the end of iteration, the integer is pulled out of the channel
		creating space for another iteration to start.
	*/

	for i := 0; i < len(d0); i++ {
		wg.Add(1) // Send a signal to the workgroup that an iteration has initiated
		f := "./" + mdl + "_" + exp + "/" + strconv.Itoa(i+1) + ".txt"
		go writeFile(sem, d0[i], d1[i], d2[i], f, &wg)
	}
	wg.Wait() // Stop "main" from exiting till all goroutines finish
	elapsed := time.Since(start)
	fmt.Printf("The call took %v to run.\n", elapsed)
}

func writeFile(sem chan int, d0 interface{}, d1 interface{}, d2 interface{}, f string, wg *sync.WaitGroup) {

	defer wg.Done()
	/*
		The defer command will always run before a function
		exits. This ensures wg always knows this gorutine
		is done, even if it encounters an error.
	*/

	sem <- 1 // Push an integer into the channel
	defer func() {
		<-sem // Pull an integer out of the channel
	}()
	/*
		The pull is inside a "defer" func making sure
		the integer is pulled out before function exits.
	*/

	file, err := os.Create(f)
	handleError(err)
	defer file.Close()

	w := csv.NewWriter(file)
	defer w.Flush()

	// Reflect value from interfaces (cannot iterate over interface type)
	v0 := reflect.ValueOf(d0)
	v1 := reflect.ValueOf(d1)
	v2 := reflect.ValueOf(d2)

	for i := 0; i < v0.Len(); i++ {
		// Write the time dimension to file across all 3 vars
		_, err := file.WriteString(fmt.Sprintf("%v, %v, %v\n", v0.Index(i), v1.Index(i), v2.Index(i)))
		handleError(err)
	}
}

func getDataSlice(file string) []interface{} {

	varName := getvarName(file)
	nc, err := netcdf.Open(file)
	handleError(err)

	defer nc.Close()

	vg, err := nc.GetVariable(varName)
	/*
		vg is a custom type composed of three entities
			Values		interface{}
			Dimensions	[]string
			Attributes	Another custom type
		The actual data is in Values
	*/

	handleError(err)

	vf := vg.Values // Extract values
	/*
		This interface is composed of []float32 slices (or other type based on netcdf type)
		The number of slices in interface is equal to the 1st dimension of netcdf variable
		Each slice is further two dimensional (dim2*dim3 of netcdf file)
	*/

	vr := reflect.ValueOf(vf)
	/*
		This stores a reflected value of the interface which can be indexed and iterated over
	*/

	var d []interface{} // Define custom type to hold all slices

	for lat := 0; lat < 144; lat++ { // Loop across 1st dim (lat)
		for lon := 0; lon < 272; lon++ { // Loop across 2nd dim (lon)
			d = append(d, vr.Index(lat).Interface().([][]float32)[lon])
			// Apend each slice of len(time) to interface type
		}
	}
	return d
}

func getvarName(file string) string {
	var varName string
	if strings.Contains(file, "pr_day") {
		varName = "pr"
	} else if strings.Contains(file, "tasmax_day") {
		varName = "tasmax"
	} else if strings.Contains(file, "tasmin_day") {
		varName = "tasmin"
	} else {
		err := errors.New("Only handling pr, tasmax, tasmin. File does not belong to any of the 3 variables")
		handleError(err)
	}
	return varName
}

func handleError(err error) {
	if err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
	return
}
