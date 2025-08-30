package http

import "net/http"

func NewRouter(resourceHandler *ResourceHandler, healthHandler *HealthHandler) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /provision", resourceHandler.Provision)

	mux.HandleFunc("GET /health", healthHandler.HealthCheck)

	return mux
}
