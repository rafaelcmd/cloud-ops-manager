package inbound

import (
	"context"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
)

type ResourceService interface {
	SendProvisioningRequest(ctx context.Context, r model.Resource) error
}
