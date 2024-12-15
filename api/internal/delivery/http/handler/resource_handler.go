package handler

import (
	"encoding/json"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/core/domain"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/core/usecase"
	"net/http"
)

type ResourceHandler struct {
	resourceUseCase usecase.ResourceUseCase
}

func NewResourceHandler(resourceUseCase usecase.ResourceUseCase) *ResourceHandler {
	return &ResourceHandler{
		resourceUseCase: resourceUseCase,
	}
}

func (h *ResourceHandler) ProvisionResource(w http.ResponseWriter, r *http.Request) {
	var resource domain.Resource
	if err := json.NewDecoder(r.Body).Decode(&resource); err != nil {
		http.Error(w, "Invalid request payload", http.StatusBadRequest)
		return
	}

	if err := h.resourceUseCase.ProvisionResource(&resource); err != nil {
		http.Error(w, "Failed to provision resource", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	err := json.NewEncoder(w).Encode(resource)
	if err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}
