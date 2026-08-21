locals {
  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
  }

  name_prefix = "${var.project}-${var.service_name}"

  # ---------------------------------------------------------------------------
  # THE DEPLOYMENT SPLIT
  # One container image, two Deployments, two IAM roles. ADR-0004 removed the
  # per-function isolation Lambda gave for free and committed to restoring it
  # this way once the GitHub adapter landed; this is that.
  #
  # The security property is narrow and worth stating plainly: nothing that runs
  # name reservations can read the GitHub App private key. A bug, a dependency
  # compromise or a malicious task payload in the state worker cannot reach the
  # credential that can create and write to repositories across the org.
  #
  # It needs a queue each. Two pods polling one queue would each receive tasks
  # meant for the other, so the IAM split would only produce AccessDenied at
  # random — the routing has to match the trust boundary.
  # ---------------------------------------------------------------------------
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
