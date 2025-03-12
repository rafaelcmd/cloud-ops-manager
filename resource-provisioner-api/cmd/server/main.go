package main

import (
	"log"
	"net/http"
)

func main() {
	//brokers := []string{"kafka:9092"}
	//topic := "resource-provisioner"

	//repo := repository.NewKafkaResourceRepository(brokers, topic)
	//defer repo.Close()

	//useCase := usecase.NewResourceUseCase(repo)

	//router := httpdelivery.SetupRoutes(useCase)
	log.Printf("Server running on port 5000")
	http.ListenAndServe(":5000", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			w.Write([]byte("Hello World"))
		} else {
			http.NotFound(w, r)
		}
	}))
}
