package usecase

import "github.com/rafaelcmd/cloud-ops-manager/api/internal/core/domain"

type ResourceRepository interface {
	CreateResource(resource *domain.Resource) error
}
