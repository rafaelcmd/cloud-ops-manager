package http

import (
	"encoding/json"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/ports/inbound"
	"net/http"
)

type ResourceHandler struct {
	resourceService inbound.ResourceService
}

func NewResourceHandler(resourceService inbound.ResourceService) *ResourceHandler {
	return &ResourceHandler{
		resourceService: resourceService,
	}
}

func (h *ResourceHandler) Provision(w http.ResponseWriter, r *http.Request) {
	var resource model.Resource
	if err := json.NewDecoder(r.Body).Decode(&resource); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	err := h.resourceService.SendProvisioningRequest(r.Context(), resource)
	if err != nil {
		http.Error(w, "Failed to process request", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusAccepted)
}
