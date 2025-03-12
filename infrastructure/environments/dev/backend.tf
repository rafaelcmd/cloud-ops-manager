terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "cloudops-manager-org"

    workspaces {
      name = "cloud-ops-manager"
    }
  }
}