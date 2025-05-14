package value_objects

type CloudProvider string

const (
	AWSCloudProvider   CloudProvider = "aws"
	AzureCloudProvider CloudProvider = "azure"
)
