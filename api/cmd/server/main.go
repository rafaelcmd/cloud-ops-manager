package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", router)
	log.Println("Server is running and listening on port 5000")
	log.Fatal(http.ListenAndServe("0.0.0.0:5000", nil))
}

func router(w http.ResponseWriter, r *http.Request) {
	handleHealthCheck(w, r)
}

func handleHealthCheck(w http.ResponseWriter, r *http.Request) {
	log.Println("Handling health check request")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
	log.Println("Health check response sent")
}
