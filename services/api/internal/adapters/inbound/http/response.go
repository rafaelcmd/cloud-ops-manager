package http

import "time"

// =============================================================================
// API RESPONSE ENVELOPE
// Standardized response wrapper for consistent API responses (DVA-C02 best practice)
// =============================================================================

// APIResponse is the standard envelope for all successful API responses
// This ensures consistent response structure across all endpoints
type APIResponse[T any] struct {
	Success bool         `json:"success"`
	Data    T            `json:"data,omitempty"`
	Meta    ResponseMeta `json:"meta"`
}

// ResponseMeta contains metadata about the API response
type ResponseMeta struct {
	RequestID  string `json:"requestId,omitempty"`
	Timestamp  string `json:"timestamp"`
	APIVersion string `json:"apiVersion"`
}

// PaginatedResponse extends APIResponse with pagination information
type PaginatedResponse[T any] struct {
	Success    bool           `json:"success"`
	Data       []T            `json:"data"`
	Meta       ResponseMeta   `json:"meta"`
	Pagination PaginationMeta `json:"pagination,omitempty"`
}

// PaginationMeta contains pagination information for list responses
type PaginationMeta struct {
	Page       int    `json:"page"`
	PerPage    int    `json:"perPage"`
	TotalItems int    `json:"totalItems"`
	TotalPages int    `json:"totalPages"`
	NextCursor string `json:"nextCursor,omitempty"`
	PrevCursor string `json:"prevCursor,omitempty"`
}

// =============================================================================
// RESPONSE BUILDER FUNCTIONS
// =============================================================================

// NewAPIResponse creates a new standardized API response
func NewAPIResponse[T any](data T, requestID string) APIResponse[T] {
	return APIResponse[T]{
		Success: true,
		Data:    data,
		Meta: ResponseMeta{
			RequestID:  requestID,
			Timestamp:  time.Now().UTC().Format(time.RFC3339),
			APIVersion: APIVersionPrefix[1:], // Remove leading "/"
		},
	}
}

// NewPaginatedResponse creates a new paginated API response
func NewPaginatedResponse[T any](data []T, requestID string, pagination PaginationMeta) PaginatedResponse[T] {
	return PaginatedResponse[T]{
		Success: true,
		Data:    data,
		Meta: ResponseMeta{
			RequestID:  requestID,
			Timestamp:  time.Now().UTC().Format(time.RFC3339),
			APIVersion: APIVersionPrefix[1:],
		},
		Pagination: pagination,
	}
}

// =============================================================================
// MESSAGE RESPONSE TYPES
// Common response structures for simple operations
// =============================================================================

// MessageResponse is used for simple success messages
type MessageResponse struct {
	Message string `json:"message"`
	Status  string `json:"status,omitempty"`
}

// CreatedResponse is returned when a resource is created
type CreatedResponse struct {
	Message    string `json:"message"`
	ResourceID string `json:"resourceId,omitempty"`
	Status     string `json:"status"`
}

// AcceptedResponse is returned for async operations (202 Accepted)
type AcceptedResponse struct {
	Message string `json:"message"`

	// RequestID is the HTTP request identifier, used for log lookup. It echoes
	// X-Request-Id when the caller supplies one.
	RequestID string `json:"requestId"`

	// ProvisionID identifies the queued work and is the only identifier that
	// follows it downstream: it travels on the message, keys the scaffolder's
	// name reservation, and names the state machine execution. It is separate
	// from RequestID because RequestID is client-supplied and so unsuitable as
	// a key.
	ProvisionID string `json:"provisionId,omitempty"`

	Status   string `json:"status"`
	TrackURL string `json:"trackUrl,omitempty"`
}
