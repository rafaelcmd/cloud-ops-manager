package main

import (
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/core/usecase"
	httpdelivery "github.com/rafaelcmd/cloud-ops-manager/api/internal/delivery/http"
	"github.com/rafaelcmd/cloud-ops-manager/api/repository"
	"log"
	"net/http"
)

func main() {
	brokers := []string{"kafka:9092"}
	topic := "resource-provisioner"

	repo := repository.NewKafkaResourceRepository(brokers, topic)
	defer repo.Close()

	useCase := usecase.NewResourceUseCase(repo)

	router := httpdelivery.SetupRoutes(useCase)
	log.Printf("Server running on port 5000")
	http.ListenAndServe(":5000", router)
}
