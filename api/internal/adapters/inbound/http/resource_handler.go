package http

import (
	"encoding/json"
	"net/http"

	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/ports/inbound"
)

type ResourceHandler struct {
	resourceService inbound.ResourceService
}

func NewResourceHandler(resourceService inbound.ResourceService) *ResourceHandler {
	return &ResourceHandler{
		resourceService: resourceService,
	}
}

// Provision godoc
// @Summary Submit a resource provisioning request
// @Description Submits a new resource provisioning request to be processed asynchronously. The request is validated and queued for processing via SQS.
// @Tags resources
// @Accept json
// @Produce plain
// @Param resource body model.Resource true "Resource provisioning request"
// @Success 202 {string} string "Request accepted for processing"
// @Failure 400 {string} string "Invalid request body"
// @Failure 500 {string} string "Failed to process request"
// @Router /provision [post]
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
