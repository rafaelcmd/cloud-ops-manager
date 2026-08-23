package outbound

import (
	"context"

	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
)

// ResourcePublisher publishes a provision request to the queue the provisioner
// consumes. A single message carries the complete request, including both the
// application and its resources; separating them is the provisioner's
// responsibility as the control plane.
type ResourcePublisher interface {
	Publish(ctx context.Context, request model.ProvisionRequest) error
}
