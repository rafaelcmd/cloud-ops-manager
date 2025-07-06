package service

import (
	"context"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/test/mocks"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSendProvisioningRequest_Success(t *testing.T) {
	// Arrange
	fakePublisher := &mocks.FakeResourcePublisher{}
	service := NewResourceService(fakePublisher)

	resource := model.Resource{
		ID:            "123",
		ResourceType:  "VM",
		CloudProvider: "AWS",
		Specification: "t2.micro",
		Status:        "pending",
		RequestedBy:   "rafael",
	}

	// Act
	err := service.SendProvisioningRequest(context.Background(), resource)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, resource, fakePublisher.LastSent)
	assert.Equal(t, 1, fakePublisher.TimesCalled)
}

func TestSendProvisioningRequest_Error(t *testing.T) {
	fakePublisher := &mocks.FakeResourcePublisher{
		ErrToReturn: assert.AnError,
	}
	service := NewResourceService(fakePublisher)

	resource := model.Resource{
		ID:            "123",
		ResourceType:  "VM",
		CloudProvider: "AWS",
		Specification: "t2.micro",
		Status:        "pending",
		RequestedBy:   "rafael",
	}

	err := service.SendProvisioningRequest(context.Background(), resource)

	assert.Error(t, err)
	assert.Equal(t, assert.AnError, err)
	assert.Equal(t, resource, fakePublisher.LastSent)
	assert.Equal(t, 1, fakePublisher.TimesCalled)
}
