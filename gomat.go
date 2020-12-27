/*
Author: Harry Singh
Summary:
Create bias-correction ready matrices from netcdf
files to feed into R MBCn algorithm.

High-level workflow
	1. Open all var.nc files from one scenario
	2. Write matrix to disk containing 3 columns (pr, tasmax, tasmin)
	3. Repeat for obs, historical and ssp245
*/

package main

import (
	"encoding/csv"
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
	mdl := os.Args[1] // GCM model name
	exp := os.Args[2] // Experiment name (historical, ssp245)

	files, _ := filepath.Glob("*" + mdl + "_" + exp + "*") // Find files in current directory matching pattern

	vr0 := getValue(files[0])
	vr1 := getValue(files[1])
	vr2 := getValue(files[2])

	var wg sync.WaitGroup
	sem := make(chan int, 1000)

	for lat := 0; lat < 144; lat++ {
		for lon := 0; lon < 272; lon++ {
			wg.Add(1)
			f := "./" + mdl + "_" + exp + "/" + strconv.Itoa(lat) + "_" + strconv.Itoa(lon) + ".txt"
			d0 := vr0.Index(lat).Interface().([][]float32)[lon]
			d1 := vr1.Index(lat).Interface().([][]float32)[lon]
			d2 := vr2.Index(lat).Interface().([][]float32)[lon]
			go writeFile(sem, d0, d1, d2, f, &wg)
		}
		wg.Wait()
	}
	elapsed := time.Since(start)
	fmt.Printf("The call took %v to run.\n", elapsed)
}

func writeFile(sem chan int, d0 []float32, d1 []float32, d2 []float32, f string, wg *sync.WaitGroup) {

	defer wg.Done()

	sem <- 1
	defer func() {
		<-sem
	}()

	file, err := os.Create(f)
	handleError(err)
	defer file.Close()

	w := csv.NewWriter(file)
	defer w.Flush()

	for i := range d0 {
		_, err := file.WriteString(fmt.Sprintf("%v, %v, %v\n", d0[i], d1[i], d2[i]))
		handleError(err)
	}
}

func getValue(file string) reflect.Value {
	varName := getvarName(file)
	nc, err := netcdf.Open(file)
	handleError(err)
	defer nc.Close()
	vg, err := nc.GetVariable(varName)
	handleError(err)
	vf := vg.Values // Extract values
	vr := reflect.ValueOf(vf)
	return vr
}

func getvarName(file string) string {
	var varName string
	if strings.Contains(file, "pr_day") {
		varName = "pr"
	} else if strings.Contains(file, "tasmax_day") {
		varName = "tasmax"
	} else {
		varName = "tasmin"
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
