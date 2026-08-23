package model

// ProvisionRequest is a request to create an application: the repository to
// scaffold and the cloud resources it requires.
//
// Both halves are submitted together because the provisioned resources'
// connection details are written into the scaffolded repository's
// configuration. The provisioner separates them after consuming the message and
// routes each half to the worker that owns it.
type ProvisionRequest struct {
	// RequestID correlates every stage of the request. It is assigned by the
	// handler and ignored if supplied by the caller: downstream it keys the
	// scaffolder's name reservation and repository claim, which are conditional
	// writes matching on request id. A caller able to set it could therefore
	// take over another caller's in-progress repository. Distinct from the HTTP
	// X-Request-Id header, which is client-supplied.
	RequestID string `json:"request_id,omitempty" swaggerignore:"true"`

	// Application describes the repository to scaffold.
	Application Application `json:"application" validate:"required"`

	// Resources are provisioned alongside the application. Optional: an
	// application without a datastore is a supported golden path.
	Resources []Resource `json:"resources,omitempty" validate:"omitempty,max=20,dive"`

	// RequestedBy identifies the person who submitted the request.
	RequestedBy string `json:"requested_by" example:"rafael" validate:"required,min=1,max=100"`
}

// Application is the repository half of a ProvisionRequest.
type Application struct {
	// Name is used as the GitHub repository name, the Kubernetes object name and
	// a DNS label, so it is validated against the most restrictive of the three
	// by the appname tag. The scaffolder applies the same rule and remains
	// authoritative; validating here returns a 400 instead of failing later in
	// the workflow.
	Name string `json:"name" example:"payments-api" validate:"required,appname"`

	// Template identifies the golden path to scaffold from. It is not
	// constrained to a fixed set here because the template catalogue belongs to
	// the scaffolder; enforcing it in the API would require deploying both
	// services to add a template.
	Template string `json:"template" example:"dotnet-consumer" validate:"required,min=1,max=100"`

	// Owner is the team or individual responsible for the repository. It is not
	// the GitHub organization, which the scaffolder reads from its own
	// configuration.
	Owner string `json:"owner" example:"team-payments" validate:"required,min=1,max=100"`

	// Description is an optional repository description. The scaffolder applies
	// a default when it is empty.
	Description string `json:"description,omitempty" example:"Payments processing service" validate:"omitempty,max=350"`
}

// Resource is a single cloud resource requested alongside an application.
type Resource struct {
	// Name identifies the resource within the application. It is scoped to the
	// request, so separate applications may reuse the same resource name.
	Name string `json:"name" example:"payments-events" validate:"required,min=1,max=100"`

	// ResourceType selects the kind of resource to provision. This list must
	// match valueobjects.ValidResourceTypes.
	ResourceType string `json:"resource_type" example:"DynamoDB" validate:"required,oneof=DynamoDB SQS SNS S3 RDS VM Lambda VPC ELB" enums:"DynamoDB,SQS,SNS,S3,RDS,VM,Lambda,VPC,ELB"`

	// CloudProvider selects the provider the resource is created in.
	CloudProvider string `json:"cloud_provider" example:"AWS" validate:"required,oneof=AWS Azure GCP" enums:"AWS,Azure,GCP"`

	// Specification holds provider-specific settings, interpreted by the infra
	// worker according to ResourceType. Key/value pairs rather than free text so
	// the worker can read individual settings without parsing.
	Specification map[string]string `json:"specification,omitempty" validate:"omitempty,max=30"`
}
