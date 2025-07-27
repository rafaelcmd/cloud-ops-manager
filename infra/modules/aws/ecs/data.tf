data "terraform_remote_state" "cloudops_manager_ecr_repository" {
  backend = "remote"
  config = {
    organization = "cloudops-manager-org"
    workspaces = {
      name = "cloudops-manager-ecr-repository"
    }
  }
}