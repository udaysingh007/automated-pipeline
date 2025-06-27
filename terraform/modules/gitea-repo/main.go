package main

import (
	"fmt"
	"log"
	"net/http"
)

func helloHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello World! - v3")
}

func main() {
	http.HandleFunc("/", helloHandler)
	
	port := "8080"
	fmt.Printf("Server starting on port %s...\n", port)
	
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal("Server failed to start:", err)
	}
}
