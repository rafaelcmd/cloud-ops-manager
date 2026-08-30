terraform {
  cloud {
    organization = "internal-developer-platform-org"

    workspaces {
      name = "internal-developer-platform-provisioner-api-dev"
    }
  }
}