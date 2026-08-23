package http

import (
	"net/http"

	"github.com/google/uuid"

	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/ports/inbound"
)

type ResourceHandler struct {
	resourceService inbound.ResourceService
}

func NewResourceHandler(resourceService inbound.ResourceService) *ResourceHandler {
	return &ResourceHandler{
		resourceService: resourceService,
	}
}

// Provision accepts a provision request for asynchronous processing. The request
// carries both the application to scaffold and the cloud resources it requires;
// the provisioner separates them after consuming the message.
func (h *ResourceHandler) Provision(w http.ResponseWriter, r *http.Request) {
	requestID := getRequestID(r)

	// Decode and validate request body
	request := DecodeAndValidate[model.ProvisionRequest](w, r, requestID)
	if request == nil {
		return // Response already sent by DecodeAndValidate
	}

	// Assigned server-side rather than taken from the HTTP request id, which
	// originates from a client-supplied X-Request-Id header. Downstream this
	// value keys the scaffolder's name reservation and repository claim, both
	// conditional writes matching on request id, so a caller able to set it
	// could take over another caller's in-progress repository.
	//
	// Generating a new id per call is safe because retries do not reach this
	// handler: the idempotency middleware replays the stored response for a
	// repeated X-Idempotency-Key. A retry sent without that header is treated as
	// a new request and fails later with a name conflict.
	request.RequestID = uuid.NewString()

	err := h.resourceService.SendProvisioningRequest(r.Context(), *request)
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, ErrorResponse{
			Code:      ErrCodeInternalError,
			Message:   "Failed to process provisioning request",
			RequestID: requestID,
		})
		return
	}

	// Both identifiers are returned: RequestID locates this call in the logs,
	// ProvisionID identifies the queued work.
	RespondWithJSON(w, http.StatusAccepted, NewAPIResponse(AcceptedResponse{
		Message:     "Request accepted for processing",
		RequestID:   requestID,
		ProvisionID: request.RequestID,
		Status:      "ACCEPTED",
	}, requestID))
}
