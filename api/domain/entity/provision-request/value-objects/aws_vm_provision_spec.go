package value_objects

import "errors"

var (
	ErrInvalidInstanceType = errors.New("invalid instance type")
	ErrInvalidAMI          = errors.New("invalid AMI")
	ErrInvalidRegion       = errors.New("invalid region")
)

type AwsVmProvisionSpec struct {
	InstanceType string `json:"instance_type"`
	AMI          string `json:"ami"`
	Region       string `json:"region"`
}

func (s *AwsVmProvisionSpec) ValidateSpec() error {
	if s.InstanceType == "" {
		return ErrInvalidInstanceType
	}
	if s.AMI == "" {
		return ErrInvalidAMI
	}
	if s.Region == "" {
		return ErrInvalidRegion
	}
	return nil
}
