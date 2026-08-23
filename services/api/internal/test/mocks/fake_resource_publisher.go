package mocks

import (
	"context"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/ports/outbound"
)

type FakeResourcePublisher struct {
	LastSent    model.ProvisionRequest
	TimesCalled int
	ErrToReturn error
}

var _ outbound.ResourcePublisher = &FakeResourcePublisher{}

func (f *FakeResourcePublisher) Publish(ctx context.Context, resource model.ProvisionRequest) error {
	f.LastSent = resource
	f.TimesCalled++
	return f.ErrToReturn
}
