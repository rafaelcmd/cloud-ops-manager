package mocks

import (
	"context"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/ports/outbound"
)

type FakeResourcePublisher struct {
	LastSent    model.Resource
	TimesCalled int
	ErrToReturn error
}

var _ outbound.ResourcePublisher = &FakeResourcePublisher{}

func (f *FakeResourcePublisher) Publish(ctx context.Context, resource model.Resource) error {
	f.LastSent = resource
	f.TimesCalled++
	return f.ErrToReturn
}
