package domain

type Resource struct {
	ID   string `json:"id"`
	ResourceType string `json:"resource_type"`
	Specification string `json:"specification"`
	Status string `json:"status"`
}
