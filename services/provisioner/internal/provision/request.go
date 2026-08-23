// Package provision defines the message contract the API publishes and the
// separation the provisioner applies to it as the platform's control plane.
//
// The contract is duplicated here rather than imported from the API. The two
// services are separate Go modules and separate deployables, and a shared type
// would make a field rename in one a compile-time break in the other. The
// trade-off is that both definitions must be updated together; each carries a
// note to that effect.
package provision

import (
	"encoding/json"
	"fmt"
	"strings"
)

// Request is a request to create an application: the repository to scaffold and
// the cloud resources it requires.
//
// Mirrors model.ProvisionRequest in services/api.
type Request struct {
	// RequestID is the correlation id assigned by the API. It keys the
	// scaffolder's name reservation and repository claim and must survive the
	// split intact.
	RequestID string `json:"request_id"`

	// Application describes the repository to scaffold.
	Application Application `json:"application"`

	// Resources are provisioned alongside the application. May be empty.
	Resources []Resource `json:"resources,omitempty"`

	// RequestedBy identifies the person who submitted the request.
	RequestedBy string `json:"requested_by"`
}

// Application is the repository half of a Request.
type Application struct {
	Name        string `json:"name"`
	Template    string `json:"template"`
	Owner       string `json:"owner"`
	Description string `json:"description,omitempty"`
}

// Resource is a single cloud resource requested alongside an application.
type Resource struct {
	Name          string            `json:"name"`
	ResourceType  string            `json:"resource_type"`
	CloudProvider string            `json:"cloud_provider"`
	Specification map[string]string `json:"specification,omitempty"`
}

// ScaffoldWork is the portion of a Request owned by the scaffolder: creating the
// repository, rendering the template and configuring its CI/CD.
type ScaffoldWork struct {
	RequestID       string
	ApplicationName string
	Template        string

	// Owner is the team responsible for the repository, used for catalog
	// metadata and CODEOWNERS. It is not the GitHub organization: the scaffolder
	// takes that from its own GITHUB_ORG configuration so that a queue message
	// cannot select the destination. It must not be mapped onto
	// RepositoryBlueprint.Owner, which denotes the organization.
	Owner string

	Description string
}

// InfraWork is the portion of a Request owned by the infra worker: provisioning
// the cloud resources with Terraform.
//
// It carries the application name even though no individual resource references
// it, because the worker names and tags the resources after the application and
// the resulting outputs are written back to that application's repository.
type InfraWork struct {
	RequestID       string
	ApplicationName string
	Resources       []Resource
}

// HasWork reports whether the request includes any infrastructure to provision.
// An application without a datastore is a supported golden path, and the state
// machine skips the infrastructure branch rather than starting an execution with
// nothing to do.
func (w InfraWork) HasWork() bool {
	return len(w.Resources) > 0
}

// ResourceTypes returns the requested resource types in order. Intended for log
// fields, where the types are enough to identify what a request asked for
// without emitting the full specification of each resource.
func (w InfraWork) ResourceTypes() []string {
	types := make([]string, 0, len(w.Resources))
	for _, resource := range w.Resources {
		types = append(types, resource.ResourceType)
	}
	return types
}

// Parse decodes a queue message into a Request and verifies the fields Split
// depends on.
//
// The API validates this shape before publishing, so a failure here indicates
// either a message produced outside the API or divergence between the two
// contract definitions.
func Parse(body []byte) (Request, error) {
	var request Request

	if err := json.Unmarshal(body, &request); err != nil {
		return Request{}, fmt.Errorf("decode provision request: %w", err)
	}

	var missing []string

	if strings.TrimSpace(request.RequestID) == "" {
		missing = append(missing, "request_id")
	}
	if strings.TrimSpace(request.Application.Name) == "" {
		missing = append(missing, "application.name")
	}
	if strings.TrimSpace(request.Application.Template) == "" {
		missing = append(missing, "application.template")
	}

	if len(missing) > 0 {
		return Request{}, fmt.Errorf("provision request is missing %s", strings.Join(missing, ", "))
	}

	return request, nil
}

// Split separates the request into the work owned by each downstream worker.
// The API submits a single request and the routing decision is made here, in the
// control plane, rather than by the caller.
//
// The two halves are independent — creating a repository does not require the
// infrastructure to exist — which allows the state machine to run them
// concurrently and join only where the infrastructure outputs are written into
// the repository.
func (r Request) Split() (ScaffoldWork, InfraWork) {
	scaffold := ScaffoldWork{
		RequestID:       r.RequestID,
		ApplicationName: r.Application.Name,
		Template:        r.Application.Template,
		Owner:           r.Application.Owner,
		Description:     r.Application.Description,
	}

	infra := InfraWork{
		RequestID:       r.RequestID,
		ApplicationName: r.Application.Name,
		Resources:       r.Resources,
	}

	return scaffold, infra
}
