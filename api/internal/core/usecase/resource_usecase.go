package usecase

import "github.com/rafaelcmd/cloud-ops-manager/api/internal/core/domain"

type ResourceUseCase struct {
	repo ResourceRepository
}

func NewResourceUseCase(repo ResourceRepository) *ResourceUseCase {
	return &ResourceUseCase{
		repo: repo,
	}
}

func (uc *ResourceUseCase) ProvisionResource(resource *domain.Resource) error {
	resource.Status = "provisioning"
	if err := uc.repo.CreateResource(resource); err != nil {
		return err
	}
	resource.Status = "provisioned"
	return nil
}
