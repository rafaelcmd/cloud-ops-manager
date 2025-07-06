package http

import "net/http"

func NewRouter(resourceHandler *ResourceHandler) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("POST /provision", resourceHandler.Provision)

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	return mux
}
