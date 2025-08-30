package model

// Resource represents a cloud resource provisioning request
// @Description Cloud resource provisioning request
type Resource struct {
	// Unique identifier for the resource
	ID string `json:"id" example:"vm-001" validate:"required,min=1,max=100"`
	// Type of cloud resource to provision
	ResourceType string `json:"resource_type" example:"VM" validate:"required,oneof=VM RDS S3 Lambda VPC ELB" enums:"VM,RDS,S3,Lambda,VPC,ELB"`
	// Cloud provider where the resource will be provisioned
	CloudProvider string `json:"cloud_provider" example:"AWS" validate:"required,oneof=AWS Azure GCP" enums:"AWS,Azure,GCP"`
	// Detailed specification of the resource configuration
	Specification string `json:"specification" example:"t2.micro" validate:"required,min=1,max=1000"`
	// Current status of the resource provisioning request
	Status string `json:"status" example:"pending" validate:"required,oneof=pending in_progress completed failed" enums:"pending,in_progress,completed,failed"`
	// Username or identifier of the person who requested the resource
	RequestedBy string `json:"requested_by" example:"rafael" validate:"required,min=1,max=100"`
}
