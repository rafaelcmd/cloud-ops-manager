terraform {
  cloud {

    organization = "cloudops-manager-org"

    workspaces {
      name = "cloudops-shared-datadog"
    }
  }
}