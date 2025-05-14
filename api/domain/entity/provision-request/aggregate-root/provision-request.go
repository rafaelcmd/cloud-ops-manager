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

type ProvisionRequest struct {
	ID       uuid.UUID                  `json:"id"`
	Type     valueObjects.ResourceType  `json:"type"`
	Provider valueObjects.CloudProvider `json:"provider"`
	Spec     interface{}                `json:"spec"`
}

func NewProvisionRequest(id uuid.UUID, resourceType valueObjects.ResourceType, provider valueObjects.CloudProvider, spec interface{}) (*ProvisionRequest, error) {
	if id == uuid.Nil {
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

	return &ProvisionRequest{
		ID:       id,
		Type:     resourceType,
		Provider: provider,
		Spec:     spec,
	}, nil
}
