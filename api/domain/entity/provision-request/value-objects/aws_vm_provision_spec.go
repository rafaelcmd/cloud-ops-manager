package value_objects

type AwsVmProvisionSpec struct {
	InstanceType string `json:"instance_type"`
	AMI          string `json:"ami"`
	Region       string `json:"region"`
}
