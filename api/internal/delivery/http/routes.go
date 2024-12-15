package http

import (
	"github.com/gorilla/mux"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/core/usecase"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/delivery/http/handler"
	"net/http"
)

func SetupRoutes(resourceUseCase *usecase.ResourceUseCase) http.Handler {
	router := mux.NewRouter()

	resourceHandler := handler.NewResourceHandler(*resourceUseCase)
	router.HandleFunc("/resources", resourceHandler.ProvisionResource).Methods("POST")

	return router
}
