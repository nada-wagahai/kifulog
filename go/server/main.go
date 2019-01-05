package main

import (
	"flag"
	"log"
	"os"
)

func init() {
	log.SetOutput(os.Stderr)

	flag.Parse()
}

func main() {
	log.Printf("hello")
}
