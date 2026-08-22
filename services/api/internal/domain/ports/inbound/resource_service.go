package inbound

import (
	"context"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
)

type ResourceService interface {
	SendProvisioningRequest(ctx context.Context, r model.ProvisionRequest) error
}
