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

	nc, err := netcdf.Open(fname) // Open netcdf file
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

	for i := 0; i < vr.Len(); i++ {
		wg.Add(1) // Send a signal to the workgroup that an iteration has initiated
		f := "./dataFiles/v" + strconv.Itoa(i) + ".txt"
		go writeData(sem, vr.Index(i).Interface().([][]float32), f, &wg)
		/*
			This will only work when you know the type is float 32
			See it with fmt.printf("T", vr.Index(0))
		*/
	}
	wg.Wait() // Stop "main" from exiting till all goroutines finish

	elapsed := time.Since(start)
	fmt.Printf("The call took %v to run.\n", elapsed)
}

func writeData(sem chan int, d [][]float32, f string, wg *sync.WaitGroup) {

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
