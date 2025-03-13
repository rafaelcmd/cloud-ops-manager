terraform {
  cloud {

    organization = "cloudops-manager-org"

    workspaces {
      name = "cloud-ops-manager-workspace"
    }
  }
}