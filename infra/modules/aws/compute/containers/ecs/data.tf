data "terraform_remote_state" "cloudops-manager-ecr-repository" {
  backend = "remote"
  config = {
    organization = "cloudops-manager-org"
    workspaces = {
      name = "cloudops-manager-ecr-repository"
    }
  }
}
