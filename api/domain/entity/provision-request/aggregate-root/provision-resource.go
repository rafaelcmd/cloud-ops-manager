package aggregate_root

import (
	"errors"
	"github.com/google/uuid"
	valueObjects "github.com/rafaelcmd/cloud-ops-manager/api/domain/entity/provision-request/value-objects"
)

var (
	ErrInvalidID            = errors.New("invalid ID")
	ErrInvalidResourceType  = errors.New("invalid resource type")
	ErrInvalidCloudProvider = errors.New("invalid cloud provider")
	ErrInvalidSpec          = errors.New("invalid spec")
)

type ProvisionSpec interface {
	ValidateSpec() error
}

type ProvisionResourceID uuid.UUID

type ProvisionResource struct {
	ID       ProvisionResourceID        `json:"id"`
	Type     valueObjects.ResourceType  `json:"type"`
	Provider valueObjects.CloudProvider `json:"provider"`
	Spec     ProvisionSpec              `json:"spec"`
}

func NewProvisionResourceID() ProvisionResourceID {
	return ProvisionResourceID(uuid.New())
}

func NewProvisionResource(id ProvisionResourceID, resourceType valueObjects.ResourceType, provider valueObjects.CloudProvider, spec ProvisionSpec) (*ProvisionResource, error) {
	if uuid.UUID(id) == uuid.Nil {
		return nil, ErrInvalidID
	}

	if resourceType == "" {
		return nil, ErrInvalidResourceType
	}

	if provider == "" {
		return nil, ErrInvalidCloudProvider
	}

	if spec == nil {
		return nil, ErrInvalidSpec
	}

	if err := spec.ValidateSpec(); err != nil {
		return nil, err
	}

	return &ProvisionResource{
		ID:       id,
		Type:     resourceType,
		Provider: provider,
		Spec:     spec,
	}, nil
}
