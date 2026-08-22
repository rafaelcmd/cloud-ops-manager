// Package valueobjects provides value objects for the domain layer.
// Value objects are immutable and defined by their attributes rather than identity.
package valueobjects

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
)

// Email represents a validated email address.
type Email struct {
	value string
}

var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)

// NewEmail creates a new Email value object.
func NewEmail(value string) (Email, error) {
	normalized := strings.ToLower(strings.TrimSpace(value))
	if normalized == "" {
		return Email{}, fmt.Errorf("email cannot be empty")
	}
	if len(normalized) > 254 {
		return Email{}, fmt.Errorf("email cannot exceed 254 characters")
	}
	if !emailRegex.MatchString(normalized) {
		return Email{}, fmt.Errorf("invalid email format")
	}
	return Email{value: normalized}, nil
}

// String returns the email as a string.
func (e Email) String() string {
	return e.value
}

// CloudProvider represents a supported cloud provider.
type CloudProvider string

const (
	CloudProviderAWS   CloudProvider = "AWS"
	CloudProviderAzure CloudProvider = "AZURE"
	CloudProviderGCP   CloudProvider = "GCP"
)

// ValidCloudProviders returns all valid cloud providers.
func ValidCloudProviders() []CloudProvider {
	return []CloudProvider{CloudProviderAWS, CloudProviderAzure, CloudProviderGCP}
}

// NewCloudProvider creates a new CloudProvider from a string.
func NewCloudProvider(value string) (CloudProvider, error) {
	normalized := strings.TrimSpace(value)
	upper := strings.ToUpper(normalized)
	switch upper {
	case string(CloudProviderAWS):
		return CloudProviderAWS, nil
	case string(CloudProviderAzure):
		return CloudProviderAzure, nil
	case string(CloudProviderGCP):
		return CloudProviderGCP, nil
	default:
		return "", fmt.Errorf("invalid cloud provider: %s (valid: AWS, Azure, GCP)", value)
	}
}

// String returns the cloud provider as a string.
func (c CloudProvider) String() string {
	return string(c)
}

// IsValid checks if the cloud provider is valid.
func (c CloudProvider) IsValid() bool {
	switch c {
	case CloudProviderAWS, CloudProviderAzure, CloudProviderGCP:
		return true
	default:
		return false
	}
}

// ResourceType represents a type of cloud resource.
type ResourceType string

const (
	// Managed services requested by the golden-path templates.
	ResourceTypeDynamoDB ResourceType = "DynamoDB"
	ResourceTypeSQS      ResourceType = "SQS"
	ResourceTypeSNS      ResourceType = "SNS"
	ResourceTypeS3       ResourceType = "S3"
	ResourceTypeRDS      ResourceType = "RDS"

	// Infrastructure primitives. Retained for compatibility; no current template
	// requests them.
	ResourceTypeVM     ResourceType = "VM"
	ResourceTypeLambda ResourceType = "Lambda"
	ResourceTypeVPC    ResourceType = "VPC"
	ResourceTypeELB    ResourceType = "ELB"
)

// ValidResourceTypes returns all valid resource types.
//
// This list must match the oneof tag on model.Resource.ResourceType, which is
// what rejects an incoming request. A type present here but absent there is
// accepted by this package and refused by the handler.
func ValidResourceTypes() []ResourceType {
	return []ResourceType{
		ResourceTypeDynamoDB,
		ResourceTypeSQS,
		ResourceTypeSNS,
		ResourceTypeS3,
		ResourceTypeRDS,
		ResourceTypeVM,
		ResourceTypeLambda,
		ResourceTypeVPC,
		ResourceTypeELB,
	}
}

// NewResourceType creates a new ResourceType from a string.
func NewResourceType(value string) (ResourceType, error) {
	normalized := strings.TrimSpace(value)
	candidate := ResourceType(normalized)
	if candidate.IsValid() {
		return candidate, nil
	}
	return "", fmt.Errorf("invalid resource type: %s", value)
}

// String returns the resource type as a string.
func (r ResourceType) String() string {
	return string(r)
}

// IsValid checks if the resource type is valid.
func (r ResourceType) IsValid() bool {
	return slices.Contains(ValidResourceTypes(), r)
}

// ProvisioningStatus represents the status of a provisioning request.
type ProvisioningStatus string

const (
	StatusPending    ProvisioningStatus = "pending"
	StatusInProgress ProvisioningStatus = "in_progress"
	StatusCompleted  ProvisioningStatus = "completed"
	StatusFailed     ProvisioningStatus = "failed"
)

// NewProvisioningStatus creates a new ProvisioningStatus from a string.
func NewProvisioningStatus(value string) (ProvisioningStatus, error) {
	normalized := strings.ToLower(strings.TrimSpace(value))
	switch ProvisioningStatus(normalized) {
	case StatusPending, StatusInProgress, StatusCompleted, StatusFailed:
		return ProvisioningStatus(normalized), nil
	default:
		return "", fmt.Errorf("invalid provisioning status: %s", value)
	}
}

// String returns the status as a string.
func (s ProvisioningStatus) String() string {
	return string(s)
}

// IsValid checks if the status is valid.
func (s ProvisioningStatus) IsValid() bool {
	switch s {
	case StatusPending, StatusInProgress, StatusCompleted, StatusFailed:
		return true
	default:
		return false
	}
}

// IsFinal checks if the status is a final state.
func (s ProvisioningStatus) IsFinal() bool {
	return s == StatusCompleted || s == StatusFailed
}

// ResourceID represents a validated resource identifier.
type ResourceID struct {
	value string
}

// NewResourceID creates a new ResourceID.
func NewResourceID(value string) (ResourceID, error) {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return ResourceID{}, fmt.Errorf("resource ID cannot be empty")
	}
	if len(trimmed) > 100 {
		return ResourceID{}, fmt.Errorf("resource ID cannot exceed 100 characters")
	}
	return ResourceID{value: trimmed}, nil
}

// String returns the resource ID as a string.
func (r ResourceID) String() string {
	return r.value
}

// Specification represents a resource specification.
type Specification struct {
	value string
}

// NewSpecification creates a new Specification.
func NewSpecification(value string) (Specification, error) {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return Specification{}, fmt.Errorf("specification cannot be empty")
	}
	if len(trimmed) > 1000 {
		return Specification{}, fmt.Errorf("specification cannot exceed 1000 characters")
	}
	return Specification{value: trimmed}, nil
}

// String returns the specification as a string.
func (s Specification) String() string {
	return s.value
}
