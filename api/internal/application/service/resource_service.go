package service

import (
	"context"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/ports/outbound"
)

type ResourceService struct {
	publisher outbound.ResourcePublisher
}

func NewResourceService(publisher outbound.ResourcePublisher) *ResourceService {
	return &ResourceService{
		publisher: publisher,
	}
}

func (s *ResourceService) SendProvisioningRequest(ctx context.Context, r model.Resource) error {
	return s.publisher.Publish(ctx, r)
}
