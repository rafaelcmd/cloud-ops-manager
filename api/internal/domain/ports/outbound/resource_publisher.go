package outbound

import (
	"context"
	"github.com/rafaelcmd/cloud-ops-manager/api/internal/domain/model"
)

type ResourcePublisher interface {
	Publish(ctx context.Context, resource model.Resource) error
}
