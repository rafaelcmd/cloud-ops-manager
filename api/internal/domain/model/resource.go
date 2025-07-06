package model

type Resource struct {
	ID            string `json:"id"`
	ResourceType  string `json:"resource_type"`
	CloudProvider string `json:"cloud_provider"`
	Specification string `json:"specification"`
	Status        string `json:"status"`
	RequestedBy   string `json:"requested_by"`
}
