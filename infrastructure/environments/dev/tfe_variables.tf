provider "tfe" {
  hostname = "app.terraform.io"
}

resource "tfe_workspace" "cloudops_workspace" {
  name         = "cloud-ops-manager-workspace"
  organization = "cloudops-manager-org"
}

resource "tfe_variable" "ec2_host" {
  workspace_id = tfe_workspace.cloudops_workspace.id
  key          = "RESOURCE_PROVISIONER_API_EC2_HOST"
  value        = module.aws_ec2.resource_provisioner_api_host
  category     = "env"
  description  = "EC2 public IP address for the application deployment pipeline."
}

resource "tfe_variable" "ec2_username" {
  workspace_id = tfe_workspace.cloudops_workspace.id
  key          = "RESOURCE_PROVISIONER_API_EC2_USERNAME"
  value        = module.aws_ec2.resource_provisioner_api_username
  category     = "env"
}

resource "tfe_variable" "ec2_private_key" {
  workspace_id = tfe_workspace.cloudops_workspace.id
  key          = "RESOURCE_PROVISIONER_API_EC2_PRIVATE_KEY"
  value        = module.aws_ec2.resource_provisioner_api_private_key
  category     = "env"
  sensitive    = true
}