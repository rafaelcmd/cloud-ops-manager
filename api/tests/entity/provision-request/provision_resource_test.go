package provisionresource_test

import (
	"errors"
	aggregateRoot "github.com/rafaelcmd/cloud-ops-manager/api/domain/entity/provision-request/aggregate-root"
	valueObjects "github.com/rafaelcmd/cloud-ops-manager/api/domain/entity/provision-request/value-objects"
	"github.com/stretchr/testify/assert"
	"testing"
)

type fakeValidSpec struct{}

func (f *fakeValidSpec) ValidateSpec() error {
	return nil
}

type fakeInvalidSpec struct{}

func (f *fakeInvalidSpec) ValidateSpec() error {
	return errors.New("invalid spec data")
}

func TestNewProvisionResource_ValidInput(t *testing.T) {
	id := aggregateRoot.NewProvisionResourceID()
	spec := &fakeValidSpec{}

	provisionResource, err := aggregateRoot.NewProvisionResource(id, valueObjects.VMResourceType, valueObjects.AWSCloudProvider, spec)

	assert.NoError(t, err)
	assert.Equal(t, id, provisionResource.ID)
	assert.Equal(t, valueObjects.VMResourceType, provisionResource.Type)
	assert.Equal(t, valueObjects.AWSCloudProvider, provisionResource.Provider)
	assert.Equal(t, spec, provisionResource.Spec)
}
