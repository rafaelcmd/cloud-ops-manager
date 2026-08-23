package http

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/test/mocks"
)

func TestProvisionerHandler_Returns202Accepted(t *testing.T) {
	// Arrange
	mockService := &mocks.FakeResourceService{}
	handler := NewResourceHandler(mockService)

	request := validProvisionRequest()
	rec := provision(t, handler, request)

	// Assert
	assert.Equal(t, http.StatusAccepted, rec.Code)
	assert.Equal(t, 1, mockService.TimesCalled)

	// Both halves of the request reach the service unchanged.
	sent := mockService.LastReceived
	assert.Equal(t, "payments-api", sent.Application.Name)
	assert.Equal(t, "dotnet-consumer", sent.Application.Template)
	assert.Len(t, sent.Resources, 2)
	assert.Equal(t, "DynamoDB", sent.Resources[0].ResourceType)
	assert.Equal(t, "PAY_PER_REQUEST", sent.Resources[0].Specification["billing_mode"])
}

func TestProvisionerHandler_MintsItsOwnRequestID(t *testing.T) {
	mockService := &mocks.FakeResourceService{}
	handler := NewResourceHandler(mockService)

	// A caller-supplied correlation id, provided both in the body and in the
	// X-Request-Id header, must be ignored. Downstream it keys the scaffolder's
	// conditional writes, so a caller able to set it could take over another
	// caller's in-progress repository.
	request := validProvisionRequest()
	request.RequestID = "attacker-chosen-id"

	body, err := json.Marshal(request)
	assert.NoError(t, err)

	req := httptest.NewRequest(http.MethodPost, "/provision", bytes.NewReader(body))
	req.Header.Set("X-Request-Id", "attacker-chosen-id")
	rec := httptest.NewRecorder()

	handler.Provision(rec, req)

	assert.Equal(t, http.StatusAccepted, rec.Code)
	assert.NotEmpty(t, mockService.LastReceived.RequestID)
	assert.NotEqual(t, "attacker-chosen-id", mockService.LastReceived.RequestID)
}

func TestProvisionerHandler_ReturnsTheProvisionIdTheWorkTravelsUnder(t *testing.T) {
	// The HTTP request id does not key the work downstream, so the response must
	// return the provision id for the caller to reference it.
	mockService := &mocks.FakeResourceService{}
	handler := NewResourceHandler(mockService)

	rec := provision(t, handler, validProvisionRequest())

	var response struct {
		Data struct {
			ProvisionID string `json:"provisionId"`
		} `json:"data"`
	}
	assert.NoError(t, json.Unmarshal(rec.Body.Bytes(), &response))
	assert.Equal(t, mockService.LastReceived.RequestID, response.Data.ProvisionID)
	assert.NotEmpty(t, response.Data.ProvisionID)
}

func TestProvisionerHandler_ResourcesAreOptional(t *testing.T) {
	// An application without a datastore is a supported golden path.
	mockService := &mocks.FakeResourceService{}
	handler := NewResourceHandler(mockService)

	request := validProvisionRequest()
	request.Resources = nil

	rec := provision(t, handler, request)

	assert.Equal(t, http.StatusAccepted, rec.Code)
	assert.Equal(t, 1, mockService.TimesCalled)
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

func TestProvisionerHandler_RejectsNamesTheScaffolderWouldReject(t *testing.T) {
	// These cases mirror ApplicationName.Parse in the scaffolder. Rejecting them
	// at the edge returns a 400 identifying the broken rule instead of failing
	// later in the workflow.
	cases := map[string]string{
		"uppercase":       "Payments-API",
		"underscore":      "payments_api",
		"leading digit":   "1payments",
		"trailing hyphen": "payments-",
		"double hyphen":   "payments--api",
		"too short":       "ab",
		"too long":        "a-very-long-application-name-that-goes-past-forty",
		"empty":           "",
	}

	for name, applicationName := range cases {
		t.Run(name, func(t *testing.T) {
			mockService := &mocks.FakeResourceService{}
			handler := NewResourceHandler(mockService)

			request := validProvisionRequest()
			request.Application.Name = applicationName

			rec := provision(t, handler, request)

			assert.Equal(t, http.StatusBadRequest, rec.Code)
			assert.Equal(t, 0, mockService.TimesCalled, "an invalid name must not reach the queue")
		})
	}
}

func TestProvisionerHandler_AcceptsNamesTheScaffolderAccepts(t *testing.T) {
	for _, applicationName := range []string{"abc", "payments-api", "a1-b2-c3", "payments2"} {
		t.Run(applicationName, func(t *testing.T) {
			handler := NewResourceHandler(&mocks.FakeResourceService{})

			request := validProvisionRequest()
			request.Application.Name = applicationName

			assert.Equal(t, http.StatusAccepted, provision(t, handler, request).Code)
		})
	}
}

func TestProvisionerHandler_RejectsAnUnknownResourceType(t *testing.T) {
	mockService := &mocks.FakeResourceService{}
	handler := NewResourceHandler(mockService)

	request := validProvisionRequest()
	request.Resources[0].ResourceType = "Mainframe"

	rec := provision(t, handler, request)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Equal(t, 0, mockService.TimesCalled)
}

func TestProvisionerHandler_RequiresTheApplicationHalf(t *testing.T) {
	mockService := &mocks.FakeResourceService{}
	handler := NewResourceHandler(mockService)

	// Resources alone are not a valid request: there is no repository to scaffold
	// and nowhere to write the resources' connection details.
	req := httptest.NewRequest(http.MethodPost, "/provision", bytes.NewBufferString(
		`{"resources":[{"name":"payments","resource_type":"DynamoDB","cloud_provider":"AWS"}],"requested_by":"rafael"}`))
	rec := httptest.NewRecorder()

	handler.Provision(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Equal(t, 0, mockService.TimesCalled)
}

func provision(t *testing.T, handler *ResourceHandler, request model.ProvisionRequest) *httptest.ResponseRecorder {
	t.Helper()

	body, err := json.Marshal(request)
	assert.NoError(t, err)

	req := httptest.NewRequest(http.MethodPost, "/provision", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	handler.Provision(rec, req)

	return rec
}

func validProvisionRequest() model.ProvisionRequest {
	return model.ProvisionRequest{
		Application: model.Application{
			Name:     "payments-api",
			Template: "dotnet-consumer",
			Owner:    "team-payments",
		},
		Resources: []model.Resource{
			{
				Name:          "payments",
				ResourceType:  "DynamoDB",
				CloudProvider: "AWS",
				Specification: map[string]string{"billing_mode": "PAY_PER_REQUEST"},
			},
			{
				Name:          "payments-events",
				ResourceType:  "SQS",
				CloudProvider: "AWS",
				Specification: map[string]string{"visibility_timeout_seconds": "30"},
			},
		},
		RequestedBy: "rafael",
	}
}
