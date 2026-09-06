# The AWS side of the Datadog integration: the role Datadog assumes to crawl
# this account, and the policies that bound what it can read. Paired with
# modules/datadog, which registers the integration on the Datadog side and
# supplies the External Id this role's trust policy pins.

resource "aws_iam_role" "datadog_integration_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::464622532012:root"
      }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# Datadog's documented baseline policy for the AWS integration:
# https://docs.datadoghq.com/integrations/amazon_web_services/
#
# Kept verbatim rather than trimmed to the services in use. A missing action
# does not fail; it silently skips resources during the crawl, so the gap shows
# up as absent dashboards rather than as an error.
resource "aws_iam_role_policy" "datadog_integration_policy" {
  name = "DatadogIntegrationPolicy"
  role = aws_iam_role.datadog_integration_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "account:GetAccountInformation",
          "airflow:GetEnvironment",
          "airflow:ListEnvironments",
          "apigateway:GET",
          "appsync:ListGraphqlApis",
          "autoscaling:Describe*",
          "backup:List*",
          "batch:DescribeJobDefinitions",
          "batch:DescribeJobQueues",
          "batch:DescribeJobs",
          "batch:ListJobs",
          "bcm-data-exports:GetExport",
          "bcm-data-exports:ListExports",
          "budgets:ViewBudget",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListDistributions",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrail",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:ListTrails",
          "cloudtrail:LookupEvents",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "codebuild:BatchGetProjects",
          "codebuild:ListProjects",
          "codedeploy:BatchGet*",
          "codedeploy:List*",
          "cost-optimization-hub:GetRecommendation",
          "cost-optimization-hub:ListRecommendations",
          "cur:DescribeReportDefinitions",
          "directconnect:Describe*",
          "dms:DescribeReplicationInstances",
          "dynamodb:Describe*",
          "dynamodb:List*",
          "ec2:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "elasticache:Describe*",
          "elasticache:List*",
          "elasticbeanstalk:DescribeEnvironments",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeTags",
          "elasticloadbalancing:Describe*",
          "elasticmapreduce:Describe*",
          "elasticmapreduce:List*",
          "es:DescribeElasticsearchDomains",
          "es:ListDomainNames",
          "es:ListTags",
          "events:CreateEventBus",
          "fsx:DescribeFileSystems",
          "fsx:ListTagsForResource",
          "glue:BatchGetJobs",
          "glue:GetJob",
          "glue:GetJobs",
          "glue:ListJobs",
          "health:DescribeAffectedEntities",
          "health:DescribeEventDetails",
          "health:DescribeEvents",
          "iam:ListAccountAliases",
          "iot:GetV2LoggingOptions",
          "kinesis:Describe*",
          "kinesis:List*",
          "lambda:List*",
          "logs:DeleteSubscriptionFilter",
          "logs:DescribeDeliveries",
          "logs:DescribeDeliverySources",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:DescribeSubscriptionFilters",
          "logs:FilterLogEvents",
          "logs:GetDeliveryDestination",
          "logs:PutSubscriptionFilter",
          "logs:TestMetricFilter",
          "network-firewall:DescribeLoggingConfiguration",
          "network-firewall:ListFirewalls",
          "oam:ListAttachedLinks",
          "oam:ListSinks",
          "organizations:Describe*",
          "organizations:List*",
          "rds:Describe*",
          "rds:List*",
          "redshift-serverless:ListNamespaces",
          "redshift:DescribeClusters",
          "redshift:DescribeLoggingStatus",
          "route53:List*",
          "route53resolver:ListResolverQueryLogConfigs",
          "s3:GetBucketLocation",
          "s3:GetBucketLogging",
          "s3:GetBucketNotification",
          "s3:GetBucketTagging",
          "s3:GetObject",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:PutBucketNotification",
          "ses:Get*",
          "ses:List*",
          "sns:GetSubscriptionAttributes",
          "sns:List*",
          "sns:Publish",
          "sqs:ListQueues",
          "ssm:GetServiceSetting",
          "ssm:ListCommands",
          "states:DescribeStateMachine",
          "states:ListStateMachines",
          "support:DescribeTrustedAdvisor*",
          "support:RefreshTrustedAdvisorCheck",
          "tag:GetResources",
          "tag:GetTagKeys",
          "tag:GetTagValues",
          "timestream:DescribeEndpoints",
          "trustedadvisor:ListRecommendationResources",
          "trustedadvisor:ListRecommendations",
          "wafv2:ListLoggingConfigurations",
          "xray:BatchGetTraces",
          "xray:GetTraceSummaries"
        ]
        Resource = "*"
      }
    ]
  })
}

# Resource collection, which is resources_config.extended_collection on the
# Datadog side, requires AWS's managed SecurityAudit policy in addition to the
# baseline above.
resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = aws_iam_role.datadog_integration_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
