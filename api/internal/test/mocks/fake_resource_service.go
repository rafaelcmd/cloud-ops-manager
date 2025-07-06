package mocks

import (
	"context"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/ports/inbound"
)

type FakeResourceService struct {
	LastReceived model.Resource
	TimesCalled  int
	ErrToReturn  error
}

var _ inbound.ResourceService = &FakeResourceService{}

func (f *FakeResourceService) SendProvisioningRequest(ctx context.Context, r model.Resource) error {
	f.LastReceived = r
	f.TimesCalled++
	return f.ErrToReturn
}
