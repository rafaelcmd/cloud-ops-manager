package service

import (
	"context"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/test/mocks"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSendProvisioningRequest_Success(t *testing.T) {
	// Arrange
	fakePublisher := &mocks.FakeResourcePublisher{}
	service := NewResourceService(fakePublisher, nil)

	request := provisionRequest()

	// Act
	err := service.SendProvisioningRequest(context.Background(), request)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, request, fakePublisher.LastSent)
	assert.Equal(t, 1, fakePublisher.TimesCalled)
}

func TestSendProvisioningRequest_Error(t *testing.T) {
	fakePublisher := &mocks.FakeResourcePublisher{
		ErrToReturn: assert.AnError,
	}
	service := NewResourceService(fakePublisher, nil)

	request := provisionRequest()

	err := service.SendProvisioningRequest(context.Background(), request)

	assert.Error(t, err)
	assert.Equal(t, assert.AnError, err)
	assert.Equal(t, request, fakePublisher.LastSent)
	assert.Equal(t, 1, fakePublisher.TimesCalled)
}

// provisionRequest returns the request shape the handler produces: an
// application to scaffold together with the resources it requires.
func provisionRequest() model.ProvisionRequest {
	return model.ProvisionRequest{
		RequestID: "11111111-1111-1111-1111-111111111111",
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
			},
		},
		RequestedBy: "rafael",
	}
}
