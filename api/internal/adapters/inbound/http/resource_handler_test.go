package http

import (
	"bytes"
	"encoding/json"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/test/mocks"
	"github.com/stretchr/testify/assert"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestProvisionerHandler_Returns202Accepted(t *testing.T) {
	// Arrange
	mockService := &mocks.FakeResourceService{}
	handler := NewResourceHandler(mockService)

	resource := model.Resource{
		ID:            "123",
		ResourceType:  "VM",
		CloudProvider: "AWS",
		Specification: "t2.micro",
		Status:        "pending",
		RequestedBy:   "rafael",
	}
	body, _ := json.Marshal(resource)
	req := httptest.NewRequest(http.MethodPost, "/provision", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	// Act
	handler.Provision(rec, req)

	// Assert
	assert.Equal(t, http.StatusAccepted, rec.Code)
	assert.Equal(t, 1, mockService.TimesCalled)
	assert.Equal(t, resource.ID, mockService.LastReceived.ID)
}

func TestProvisionerHandler_Returns400BadRequest(t *testing.T) {
	// Arrange
	handler := NewResourceHandler(&mocks.FakeResourceService{})

	req := httptest.NewRequest(http.MethodPost, "/provision", bytes.NewBufferString("invalid json"))
	rec := httptest.NewRecorder()

	// Act
	handler.Provision(rec, req)

	// Assert
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}
