# WAFv2 Web ACL associated with the API Gateway stage. Rejects malformed and
# abusive traffic at the edge so it never reaches the API pods or consumes a
# Fargate request slot.
#
# The default action is allow, so rules are exceptions rather than an allowlist.
# Priorities are evaluated in ascending order and the first terminating action
# wins, which is why rate limiting sits after the managed rule groups.

resource "aws_wafv2_web_acl" "api" {
  name        = var.web_acl_name
  description = var.web_acl_description
  scope       = "REGIONAL" # Required for API Gateway

  default_action {
    allow {}
  }

  # AWS-maintained coverage for common web exploits, roughly the OWASP Top 10.
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"

        # Overridden to count rather than removed, so a rule that produces
        # false positives against JSON API traffic still reports what it would
        # have blocked.
        dynamic "rule_action_override" {
          for_each = var.common_rules_excluded
          content {
            name = rule_action_override.value
            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.web_acl_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Signatures for request patterns associated with known exploits, including
  # host header and Log4j-style injection attempts.
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.web_acl_name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Per-IP request ceiling over a five-minute sliding window. This is the only
  # rule that bounds cost: without it a single client can drive unlimited
  # gateway requests and Fargate scaling.
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate-limited"
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_requests
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.web_acl_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Rejects oversized bodies before the API deserializes them.
  rule {
    name     = "RequestSizeConstraint"
    priority = 4

    action {
      block {
        custom_response {
          response_code            = 413
          custom_response_body_key = "request-too-large"
        }
      }
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {
            oversize_handling = "MATCH"
          }
        }
        comparison_operator = "GT"
        size                = var.max_request_body_size
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.web_acl_name}-size-constraint"
      sampled_requests_enabled   = true
    }
  }

  # Dedicated SQL injection rule group, layered on top of the common rule set's
  # own SQLi coverage.
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.web_acl_name}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # A blocked request is answered by WAF, not by the API, so these bodies exist
  # to keep the JSON error shape consistent with what the API itself returns.
  custom_response_body {
    key = "rate-limited"
    content = jsonencode({
      code    = "RATE_LIMITED"
      message = "Too many requests. Please try again later."
    })
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key = "request-too-large"
    content = jsonencode({
      code    = "REQUEST_TOO_LARGE"
      message = "Request body exceeds maximum allowed size."
    })
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key = "blocked"
    content = jsonencode({
      code    = "BLOCKED"
      message = "Request blocked by security policy."
    })
    content_type = "APPLICATION_JSON"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.web_acl_name
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name        = var.web_acl_name
    Project     = var.project
    Environment = var.environment
  })
}

# WAF refuses to log to a group whose name does not begin with
# "aws-waf-logs-", so the prefix below is a hard requirement, not a convention.

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_logging ? 1 : 0

  name              = "aws-waf-logs-${var.web_acl_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "aws-waf-logs-${var.web_acl_name}"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "waf" {
  count = var.enable_logging ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.api.arn

  # Only blocked requests are logged. Allowed traffic is already in the API
  # Gateway access logs, so logging it twice adds cost without adding signal.
  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      condition {
        action_condition {
          action = "COUNT"
        }
      }
    }
  }
}
