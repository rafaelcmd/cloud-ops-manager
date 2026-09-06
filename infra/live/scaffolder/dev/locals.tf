locals {
  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }

  name_prefix = "${var.project}-${var.service_name}"

  # One container image, two Deployments, two IAM roles.
  #
  # The property this buys: nothing that runs name reservations can read the
  # GitHub App private key. A bug, a compromised dependency or a hostile task
  # payload in the state worker cannot reach the credential that can create and
  # write to repositories across the organisation.
  #
  # Each worker needs its own queue for this to hold. Two pods polling one queue
  # would each receive tasks meant for the other, and the IAM split would then
  # surface as AccessDenied at random rather than as a boundary. Routing has to
  # match the trust boundary.
  #
  # See docs/adr/0004-scaffolder-runs-as-a-container-on-eks.md for why the
  # service is a container rather than a set of Lambda functions.
  workers = {
    state = {
      description          = "name reservations and other state-only tasks"
      reads_github_app_key = false
    }
    github = {
      description          = "repository creation and everything else that talks to GitHub"
      reads_github_app_key = true
    }
  }
}
