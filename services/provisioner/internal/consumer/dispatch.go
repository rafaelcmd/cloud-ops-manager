package consumer

import (
	"context"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"

	"github.com/rafaelcmd/internal-developer-platform/resource-provisioner-service/internal/logger"
	"github.com/rafaelcmd/internal-developer-platform/resource-provisioner-service/internal/provision"
)

// Dispatch performs the control-plane step: it decodes the request published by
// the API and separates it into the work owned by each downstream worker.
//
// It is shared by the SQS and Kafka consume loops so that local development
// exercises the same code path as the deployed environments.
//
// The return value reports whether the message could be decoded, not whether the
// work was carried out. The scaffold state machine does not exist yet, so both
// halves are logged and the message is acknowledged; the corresponding
// StartExecution calls belong where the logging is.
func Dispatch(ctx context.Context, body []byte, tracer trace.Tracer, log logger.Logger) bool {
	request, err := provision.Parse(body)
	if err != nil {
		// The API validates this shape before publishing, so a failure here
		// indicates a message produced outside the API or divergence between the
		// two contract definitions. Neither is resolved by a retry.
		//
		// Returning false leaves the message on the queue. It used to be
		// acknowledged here, because the queue had no dead-letter queue and the
		// alternative was redelivering forever; the queue has one now, so the
		// redrive policy takes the message out of circulation after
		// maxReceiveCount and puts it somewhere it can be read.
		log.WithContext(ctx).Error("could not understand provision request",
			logger.F("error", err.Error()),
			logger.F("body", string(body)),
		)
		return false
	}

	scaffold, infra := request.Split()

	_, span := tracer.Start(ctx, "SplitProvisionRequest")
	defer span.End()

	span.SetAttributes(
		attribute.String("provision.request_id", request.RequestID),
		attribute.String("provision.application", scaffold.ApplicationName),
		attribute.String("provision.template", scaffold.Template),
		attribute.Int("provision.resource_count", len(infra.Resources)),
	)

	// One entry per half, so the logs show the request as it will execute: a
	// scaffold branch and an infrastructure branch sharing a request id and a
	// trace.
	log.WithContext(ctx).Info("scaffold work",
		logger.F("request_id", scaffold.RequestID),
		logger.F("application_name", scaffold.ApplicationName),
		logger.F("template", scaffold.Template),
		logger.F("owner", scaffold.Owner),
	)

	if infra.HasWork() {
		log.WithContext(ctx).Info("infrastructure work",
			logger.F("request_id", infra.RequestID),
			logger.F("application_name", infra.ApplicationName),
			logger.F("resource_count", len(infra.Resources)),
			logger.F("resource_types", infra.ResourceTypes()),
		)
	} else {
		// Logged explicitly so that a request with no resources is
		// distinguishable from resources lost during the split.
		log.WithContext(ctx).Info("no infrastructure work",
			logger.F("request_id", infra.RequestID),
			logger.F("application_name", infra.ApplicationName),
		)
	}

	return true
}
