package mocks

import (
	"context"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/ports/inbound"
)

type FakeResourceService struct {
	LastReceived model.ProvisionRequest
	TimesCalled  int
	ErrToReturn  error
}

var _ inbound.ResourceService = &FakeResourceService{}

func (f *FakeResourceService) SendProvisioningRequest(ctx context.Context, r model.ProvisionRequest) error {
	f.LastReceived = r
	f.TimesCalled++
	return f.ErrToReturn
}
