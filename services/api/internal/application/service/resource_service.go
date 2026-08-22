package service

import (
	"context"
	"encoding/json"

	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/model"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/domain/ports/outbound"
	"github.com/rafaelcmd/internal-developer-platform/api/internal/logger"
)

type ResourceService struct {
	publisher outbound.ResourcePublisher
	logger    logger.Logger
}

func NewResourceService(publisher outbound.ResourcePublisher, log logger.Logger) *ResourceService {
	if log == nil {
		log = logger.NopLogger{}
	}
	return &ResourceService{
		publisher: publisher,
		logger:    log,
	}
}

func (s *ResourceService) SendProvisioningRequest(ctx context.Context, r model.ProvisionRequest) error {
	// Log the payload we're about to publish, mirroring the "received message"
	// body log on the provisioner side. The request context is attached so the
	// OTel bridge stamps the same trace_id the provisioner will log against,
	// giving one correlated body log on each end of the queue.
	body, _ := json.Marshal(r)
	s.logger.WithContext(ctx).Info("publishing provisioning request",
		logger.F("request_id", r.RequestID),
		logger.F("application_name", r.Application.Name),
		logger.F("template", r.Application.Template),
		logger.F("resource_count", len(r.Resources)),
		logger.F("body", string(body)),
	)

	return s.publisher.Publish(ctx, r)
}
