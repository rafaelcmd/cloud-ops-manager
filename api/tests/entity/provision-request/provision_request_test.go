package provisionrequest_test

import (
	"github.com/google/uuid"
	aggregateRoot "github.com/rafaelcmd/cloud-ops-manager/api/domain/entity/provision-request/aggregate-root"
	valueObjects "github.com/rafaelcmd/cloud-ops-manager/api/domain/entity/provision-request/value-objects"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestNewProvisionRequest_ValidInput(t *testing.T) {
	id := uuid.New()
	spec := valueObjects.AwsVmProvisionSpec{
		InstanceType: "t2.micro",
		AMI:          "ami-12345678",
		Region:       "us-west-2",
	}

	provisionRequest, err := aggregateRoot.NewProvisionRequest(id, valueObjects.VMResourceType, valueObjects.AWSCloudProvider, spec)

	assert.NoError(t, err)
	assert.Equal(t, id, provisionRequest.ID)
	assert.Equal(t, valueObjects.VMResourceType, provisionRequest.Type)
	assert.Equal(t, valueObjects.AWSCloudProvider, provisionRequest.Provider)
	assert.Equal(t, spec, provisionRequest.Spec)
}
