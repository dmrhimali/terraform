https://docs.datadoghq.com/serverless/aws_lambda/opentelemetry?tab=python

http://docs.datadoghq.com/tracing/trace_collection/custom_instrumentation/python/otel/

https://docs.datadoghq.com/tracing/trace_collection/automatic_instrumentation/dd_libraries/python/

https://opentelemetry.io/docs/platforms/faas/lambda-auto-instrument/

https://pypi.org/project/opentelemetry-instrumentation-aws-lambda/

https://github.com/open-telemetry/opentelemetry-lambda/tree/main/python

https://opentelemetry.io/docs/languages/python/



### Create your Datadog Api key:
- (Create and) Log in to your Datadog account (e.g., at app.datadoghq.com for the US region or app.datadoghq.eu for the EU region).
- Navigate to your account home> personal settings changed to Organization Settings > API Keys (usually under your user profile or Integrations).
- Create a new API key or copy an existing one. It’s a 32-character alphanumeric string, e.g., a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.
- Do not share this key publicly—it’s sensitive and grants access to your Datadog account.

### Create a Datadog Application Key :
- Log in to your Datadog account.
- Navigate to Organization Settings > Application Keys.
- Click New Key, provide a descriptive name (e.g., "Terraform"), and click Create Key.
- Securely copy the generated Application Key, as it will not be retrievable later.

### integrate aws to datadog
If you haven’t already, set up the Amazon Web Services integration first.

You can obtain the terraform code for this in Dtadig site:
- got to [us5.da](https://us5.datadoghq.com/)
- search `integrations`
- select `aws`
- select `terraform`
- select your app and api keys.
- Datadog site will generate the terraform you need to add to your tf script here and apply

![img](img/out01.jpg)

Add the tf generated to your terraform script (`lambda-datadog.tf`)for runnig:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

provider "aws" {}

provider "datadog" {
  api_key = "99242b5ededcbbc2b41e69c9f28b6591"
  app_key = "59efa3baa84790b9ac88eda26b84534d22010659"
}

data "aws_iam_policy_document" "datadog_aws_integration_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::464622532012:root"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values = [
        "${datadog_integration_aws_account.datadog_integration.auth_config.aws_auth_config_role.external_id}"
      ]
    }
  }
}

data "aws_iam_policy_document" "datadog_aws_integration" {
  statement {
    actions = [
      "apigateway:GET",
      "aoss:BatchGetCollection",
      "aoss:ListCollections",
      "autoscaling:Describe*",
      "backup:List*",
      "bcm-data-exports:GetExport",
      "bcm-data-exports:ListExports",
      "bedrock:GetAgent",
      "bedrock:GetAgentAlias",
      "bedrock:GetFlow",
      "bedrock:GetFlowAlias",
      "bedrock:GetGuardrail",
      "bedrock:GetImportedModel",
      "bedrock:GetInferenceProfile",
      "bedrock:GetMarketplaceModelEndpoint",
      "bedrock:ListAgentAliases",
      "bedrock:ListAgents",
      "bedrock:ListFlowAliases",
      "bedrock:ListFlows",
      "bedrock:ListGuardrails",
      "bedrock:ListImportedModels",
      "bedrock:ListInferenceProfiles",
      "bedrock:ListMarketplaceModelEndpoints",
      "bedrock:ListPromptRouters",
      "bedrock:ListProvisionedModelThroughputs",
      "budgets:ViewBudget",
      "cassandra:Select",
      "cloudfront:GetDistributionConfig",
      "cloudfront:ListDistributions",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "codeartifact:DescribeDomain",
      "codeartifact:DescribePackageGroup",
      "codeartifact:DescribeRepository",
      "codeartifact:ListDomains",
      "codeartifact:ListPackageGroups",
      "codeartifact:ListPackages",
      "codedeploy:BatchGet*",
      "codedeploy:List*",
      "codepipeline:ListWebhooks",
      "cur:DescribeReportDefinitions",
      "directconnect:Describe*",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "ec2:Describe*",
      "ec2:GetAllowedImagesSettings",
      "ec2:GetEbsDefaultKmsKeyId",
      "ec2:GetInstanceMetadataDefaults",
      "ec2:GetSerialConsoleAccessStatus",
      "ec2:GetSnapshotBlockPublicAccessState",
      "ec2:GetTransitGatewayPrefixListReferences",
      "ec2:SearchTransitGatewayRoutes",
      "ecs:Describe*",
      "ecs:List*",
      "elasticache:Describe*",
      "elasticache:List*",
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeTags",
      "elasticloadbalancing:Describe*",
      "elasticmapreduce:Describe*",
      "elasticmapreduce:List*",
      "emr-containers:ListManagedEndpoints",
      "emr-containers:ListSecurityConfigurations",
      "emr-containers:ListVirtualClusters",
      "es:DescribeElasticsearchDomains",
      "es:ListDomainNames",
      "es:ListTags",
      "events:CreateEventBus",
      "fsx:DescribeFileSystems",
      "fsx:ListTagsForResource",
      "glacier:GetVaultNotifications",
      "glue:ListRegistries",
      "grafana:DescribeWorkspace",
      "greengrass:GetComponent",
      "greengrass:GetConnectivityInfo",
      "greengrass:GetCoreDevice",
      "greengrass:GetDeployment",
      "health:DescribeAffectedEntities",
      "health:DescribeEventDetails",
      "health:DescribeEvents",
      "kinesis:Describe*",
      "kinesis:List*",
      "lambda:GetPolicy",
      "lambda:List*",
      "lightsail:GetInstancePortStates",
      "logs:DeleteSubscriptionFilter",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:DescribeSubscriptionFilters",
      "logs:FilterLogEvents",
      "logs:PutSubscriptionFilter",
      "logs:TestMetricFilter",
      "macie2:GetAllowList",
      "macie2:GetCustomDataIdentifier",
      "macie2:ListAllowLists",
      "macie2:ListCustomDataIdentifiers",
      "macie2:ListMembers",
      "macie2:GetMacieSession",
      "managedblockchain:GetAccessor",
      "managedblockchain:GetMember",
      "managedblockchain:GetNetwork",
      "managedblockchain:GetNode",
      "managedblockchain:GetProposal",
      "managedblockchain:ListAccessors",
      "managedblockchain:ListInvitations",
      "managedblockchain:ListMembers",
      "managedblockchain:ListNodes",
      "managedblockchain:ListProposals",
      "memorydb:DescribeAcls",
      "memorydb:DescribeMultiRegionClusters",
      "memorydb:DescribeParameterGroups",
      "memorydb:DescribeReservedNodes",
      "memorydb:DescribeSnapshots",
      "memorydb:DescribeSubnetGroups",
      "memorydb:DescribeUsers",
      "oam:ListAttachedLinks",
      "oam:ListSinks",
      "organizations:Describe*",
      "organizations:List*",
      "osis:GetPipeline",
      "osis:GetPipelineBlueprint",
      "osis:ListPipelineBlueprints",
      "osis:ListPipelines",
      "proton:GetComponent",
      "proton:GetDeployment",
      "proton:GetEnvironment",
      "proton:GetEnvironmentAccountConnection",
      "proton:GetEnvironmentTemplate",
      "proton:GetEnvironmentTemplateVersion",
      "proton:GetRepository",
      "proton:GetService",
      "proton:GetServiceInstance",
      "proton:GetServiceTemplate",
      "proton:GetServiceTemplateVersion",
      "proton:ListComponents",
      "proton:ListDeployments",
      "proton:ListEnvironmentAccountConnections",
      "proton:ListEnvironmentTemplateVersions",
      "proton:ListEnvironmentTemplates",
      "proton:ListEnvironments",
      "proton:ListRepositories",
      "proton:ListServiceInstances",
      "proton:ListServiceTemplateVersions",
      "proton:ListServiceTemplates",
      "proton:ListServices",
      "qldb:ListJournalKinesisStreamsForLedger",
      "rds:Describe*",
      "rds:List*",
      "redshift:DescribeClusters",
      "redshift:DescribeLoggingStatus",
      "redshift-serverless:ListEndpointAccess",
      "redshift-serverless:ListManagedWorkgroups",
      "redshift-serverless:ListNamespaces",
      "redshift-serverless:ListRecoveryPoints",
      "redshift-serverless:ListSnapshots",
      "route53:List*",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketTagging",
      "s3:ListAccessGrants",
      "s3:ListAllMyBuckets",
      "s3:PutBucketNotification",
      "s3express:GetBucketPolicy",
      "s3express:GetEncryptionConfiguration",
      "s3express:ListAllMyDirectoryBuckets",
      "s3tables:GetTableBucketMaintenanceConfiguration",
      "s3tables:ListTableBuckets",
      "s3tables:ListTables",
      "savingsplans:DescribeSavingsPlanRates",
      "savingsplans:DescribeSavingsPlans",
      "secretsmanager:GetResourcePolicy",
      "ses:Get*",
      "ses:ListAddonInstances",
      "ses:ListAddonSubscriptions",
      "ses:ListAddressLists",
      "ses:ListArchives",
      "ses:ListContactLists",
      "ses:ListCustomVerificationEmailTemplates",
      "ses:ListMultiRegionEndpoints",
      "ses:ListIngressPoints",
      "ses:ListRelays",
      "ses:ListRuleSets",
      "ses:ListTemplates",
      "ses:ListTrafficPolicies",
      "sns:GetSubscriptionAttributes",
      "sns:List*",
      "sns:Publish",
      "sqs:ListQueues",
      "states:DescribeStateMachine",
      "states:ListStateMachines",
      "support:DescribeTrustedAdvisor*",
      "support:RefreshTrustedAdvisorCheck",
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues",
      "timestream:DescribeEndpoints",
      "timestream:ListTables",
      "waf-regional:GetRule",
      "waf-regional:GetRuleGroup",
      "waf-regional:ListRuleGroups",
      "waf-regional:ListRules",
      "waf:GetRule",
      "waf:GetRuleGroup",
      "waf:ListRuleGroups",
      "waf:ListRules",
      "wafv2:GetIPSet",
      "wafv2:GetLoggingConfiguration",
      "wafv2:GetRegexPatternSet",
      "wafv2:GetRuleGroup",
      "wafv2:ListLoggingConfigurations",
      "workmail:DescribeOrganization",
      "workmail:ListOrganizations",
      "xray:BatchGetTraces",
      "xray:GetTraceSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "datadog_aws_integration" {
  name   = "DatadogAWSIntegrationPolicy"
  policy = data.aws_iam_policy_document.datadog_aws_integration.json
}
resource "aws_iam_role" "datadog_aws_integration" {
  name               = "DatadogIntegrationRole"
  description        = "Role for Datadog AWS Integration"
  assume_role_policy = data.aws_iam_policy_document.datadog_aws_integration_assume_role.json
}
resource "aws_iam_role_policy_attachment" "datadog_aws_integration" {
  role       = aws_iam_role.datadog_aws_integration.name
  policy_arn = aws_iam_policy.datadog_aws_integration.arn
}
resource "aws_iam_role_policy_attachment" "datadog_aws_integration_security_audit" {
  role       = aws_iam_role.datadog_aws_integration.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "datadog_integration_aws_account" "datadog_integration" {
  account_tags   = []
  aws_account_id = "545200963109"
  aws_partition  = "aws"
  aws_regions {
    include_all = true
  }
  auth_config {
    aws_auth_config_role {
      role_name = "DatadogIntegrationRole"
    }
  }
    resources_config {
    cloud_security_posture_management_collection = true
    extended_collection                          = true
  }
  traces_config {
    xray_services {
    }
  }
    logs_config {
    lambda_forwarder {
    }
  }
  metrics_config {
    namespace_filters {
    }
  }
}
```
https://us5.datadoghq.com/integrations?category=AWS 

### create lambda

`src/app.py:`

```py
import json
from datadog_lambda.metric import lambda_metric  # For custom metrics
from ddtrace import tracer  # For tracing/custom spans
import time  # Example import; trace as needed

@tracer.wrap()  # Auto-wraps the function for tracing
def lambda_handler(event, context):
    # Get current span for tags (e.g., for business logic)
    current_span = tracer.current_span()
    if current_span:
        current_span.set_tag('custom.tag', 'value')  # Add tags to Lambda span

    # Example: Custom span
    with tracer.trace("custom.operation") as span:
        span.set_tag('operation.type', 'example')
        time.sleep(0.1)  # Simulate work

    # Example: Submit custom metric (async, no overhead)
    lambda_metric(
        metric_name='myapp.order_value',
        value=42.99,
        tags=['env:prod', 'service:my-lambda']
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from instrumented Lambda!')
    }
```

### Create a Custom OTel Lambda Layer
Since the Datadog Python layer (`datadog_python_layer_version = 114`) doesn’t include `opentelemetry-api` or `opentelemetry-sdk`, create a custom layer for these dependencies.

1. **Set Up the Layer Directory**:
   ```bash
   mkdir -p otel-layer/python/lib/python3.13/site-packages
   cd otel-layer
   ```
2. **Create `requirements.txt`**:
   ```text
   opentelemetry-api==1.27.0
   opentelemetry-sdk==1.27.0
   ```
3. **Install Dependencies**:
   ```bash
   python3 -m pip install -r requirements.txt -t python/lib/python3.13/site-packages/
   ```
4. **Create the Layer ZIP**:
   ```bash
   cd otel-layer
   zip -r ../otel-layer.zip python/
   ```
   - This creates `otel-layer.zip` in the parent directory.

5. **Update Terraform Configuration**
    Update  Terraform configuration to include the custom OTel layer.


Terraform:

```terraform


# Terraform 0.13+ uses the Terraform Registry:
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }
}



provider "aws" {
  region = "us-east-1"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}/"
}

data "aws_iam_policy_document" "datadog_aws_integration_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::464622532012:root"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values = [
        "${datadog_integration_aws_account.datadog_integration.auth_config.aws_auth_config_role.external_id}"
      ]
    }
  }
}

data "aws_iam_policy_document" "datadog_aws_integration" {
  statement {
    actions = [
      "apigateway:GET",
      "aoss:BatchGetCollection",
      "aoss:ListCollections",
      "autoscaling:Describe*",
      "backup:List*",
      "bcm-data-exports:GetExport",
      "bcm-data-exports:ListExports",
      "bedrock:GetAgent",
      "bedrock:GetAgentAlias",
      "bedrock:GetFlow",
      "bedrock:GetFlowAlias",
      "bedrock:GetGuardrail",
      "bedrock:GetImportedModel",
      "bedrock:GetInferenceProfile",
      "bedrock:GetMarketplaceModelEndpoint",
      "bedrock:ListAgentAliases",
      "bedrock:ListAgents",
      "bedrock:ListFlowAliases",
      "bedrock:ListFlows",
      "bedrock:ListGuardrails",
      "bedrock:ListImportedModels",
      "bedrock:ListInferenceProfiles",
      "bedrock:ListMarketplaceModelEndpoints",
      "bedrock:ListPromptRouters",
      "bedrock:ListProvisionedModelThroughputs",
      "budgets:ViewBudget",
      "cassandra:Select",
      "cloudfront:GetDistributionConfig",
      "cloudfront:ListDistributions",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "codeartifact:DescribeDomain",
      "codeartifact:DescribePackageGroup",
      "codeartifact:DescribeRepository",
      "codeartifact:ListDomains",
      "codeartifact:ListPackageGroups",
      "codeartifact:ListPackages",
      "codedeploy:BatchGet*",
      "codedeploy:List*",
      "codepipeline:ListWebhooks",
      "cur:DescribeReportDefinitions",
      "directconnect:Describe*",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "ec2:Describe*",
      "ec2:GetAllowedImagesSettings",
      "ec2:GetEbsDefaultKmsKeyId",
      "ec2:GetInstanceMetadataDefaults",
      "ec2:GetSerialConsoleAccessStatus",
      "ec2:GetSnapshotBlockPublicAccessState",
      "ec2:GetTransitGatewayPrefixListReferences",
      "ec2:SearchTransitGatewayRoutes",
      "ecs:Describe*",
      "ecs:List*",
      "elasticache:Describe*",
      "elasticache:List*",
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeTags",
      "elasticloadbalancing:Describe*",
      "elasticmapreduce:Describe*",
      "elasticmapreduce:List*",
      "emr-containers:ListManagedEndpoints",
      "emr-containers:ListSecurityConfigurations",
      "emr-containers:ListVirtualClusters",
      "es:DescribeElasticsearchDomains",
      "es:ListDomainNames",
      "es:ListTags",
      "events:CreateEventBus",
      "fsx:DescribeFileSystems",
      "fsx:ListTagsForResource",
      "glacier:GetVaultNotifications",
      "glue:ListRegistries",
      "grafana:DescribeWorkspace",
      "greengrass:GetComponent",
      "greengrass:GetConnectivityInfo",
      "greengrass:GetCoreDevice",
      "greengrass:GetDeployment",
      "health:DescribeAffectedEntities",
      "health:DescribeEventDetails",
      "health:DescribeEvents",
      "kinesis:Describe*",
      "kinesis:List*",
      "lambda:GetPolicy",
      "lambda:List*",
      "lightsail:GetInstancePortStates",
      "logs:DeleteSubscriptionFilter",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:DescribeSubscriptionFilters",
      "logs:FilterLogEvents",
      "logs:PutSubscriptionFilter",
      "logs:TestMetricFilter",
      "macie2:GetAllowList",
      "macie2:GetCustomDataIdentifier",
      "macie2:ListAllowLists",
      "macie2:ListCustomDataIdentifiers",
      "macie2:ListMembers",
      "macie2:GetMacieSession",
      "managedblockchain:GetAccessor",
      "managedblockchain:GetMember",
      "managedblockchain:GetNetwork",
      "managedblockchain:GetNode",
      "managedblockchain:GetProposal",
      "managedblockchain:ListAccessors",
      "managedblockchain:ListInvitations",
      "managedblockchain:ListMembers",
      "managedblockchain:ListNodes",
      "managedblockchain:ListProposals",
      "memorydb:DescribeAcls",
      "memorydb:DescribeMultiRegionClusters",
      "memorydb:DescribeParameterGroups",
      "memorydb:DescribeReservedNodes",
      "memorydb:DescribeSnapshots",
      "memorydb:DescribeSubnetGroups",
      "memorydb:DescribeUsers",
      "oam:ListAttachedLinks",
      "oam:ListSinks",
      "organizations:Describe*",
      "organizations:List*",
      "osis:GetPipeline",
      "osis:GetPipelineBlueprint",
      "osis:ListPipelineBlueprints",
      "osis:ListPipelines",
      "proton:GetComponent",
      "proton:GetDeployment",
      "proton:GetEnvironment",
      "proton:GetEnvironmentAccountConnection",
      "proton:GetEnvironmentTemplate",
      "proton:GetEnvironmentTemplateVersion",
      "proton:GetRepository",
      "proton:GetService",
      "proton:GetServiceInstance",
      "proton:GetServiceTemplate",
      "proton:GetServiceTemplateVersion",
      "proton:ListComponents",
      "proton:ListDeployments",
      "proton:ListEnvironmentAccountConnections",
      "proton:ListEnvironmentTemplateVersions",
      "proton:ListEnvironmentTemplates",
      "proton:ListEnvironments",
      "proton:ListRepositories",
      "proton:ListServiceInstances",
      "proton:ListServiceTemplateVersions",
      "proton:ListServiceTemplates",
      "proton:ListServices",
      "qldb:ListJournalKinesisStreamsForLedger",
      "rds:Describe*",
      "rds:List*",
      "redshift:DescribeClusters",
      "redshift:DescribeLoggingStatus",
      "redshift-serverless:ListEndpointAccess",
      "redshift-serverless:ListManagedWorkgroups",
      "redshift-serverless:ListNamespaces",
      "redshift-serverless:ListRecoveryPoints",
      "redshift-serverless:ListSnapshots",
      "route53:List*",
      "s3:GetBucketLocation",
      "s3:GetBucketLogging",
      "s3:GetBucketNotification",
      "s3:GetBucketTagging",
      "s3:ListAccessGrants",
      "s3:ListAllMyBuckets",
      "s3:PutBucketNotification",
      "s3express:GetBucketPolicy",
      "s3express:GetEncryptionConfiguration",
      "s3express:ListAllMyDirectoryBuckets",
      "s3tables:GetTableBucketMaintenanceConfiguration",
      "s3tables:ListTableBuckets",
      "s3tables:ListTables",
      "savingsplans:DescribeSavingsPlanRates",
      "savingsplans:DescribeSavingsPlans",
      "secretsmanager:GetResourcePolicy",
      "ses:Get*",
      "ses:ListAddonInstances",
      "ses:ListAddonSubscriptions",
      "ses:ListAddressLists",
      "ses:ListArchives",
      "ses:ListContactLists",
      "ses:ListCustomVerificationEmailTemplates",
      "ses:ListMultiRegionEndpoints",
      "ses:ListIngressPoints",
      "ses:ListRelays",
      "ses:ListRuleSets",
      "ses:ListTemplates",
      "ses:ListTrafficPolicies",
      "sns:GetSubscriptionAttributes",
      "sns:List*",
      "sns:Publish",
      "sqs:ListQueues",
      "states:DescribeStateMachine",
      "states:ListStateMachines",
      "support:DescribeTrustedAdvisor*",
      "support:RefreshTrustedAdvisorCheck",
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues",
      "timestream:DescribeEndpoints",
      "timestream:ListTables",
      "waf-regional:GetRule",
      "waf-regional:GetRuleGroup",
      "waf-regional:ListRuleGroups",
      "waf-regional:ListRules",
      "waf:GetRule",
      "waf:GetRuleGroup",
      "waf:ListRuleGroups",
      "waf:ListRules",
      "wafv2:GetIPSet",
      "wafv2:GetLoggingConfiguration",
      "wafv2:GetRegexPatternSet",
      "wafv2:GetRuleGroup",
      "wafv2:ListLoggingConfigurations",
      "workmail:DescribeOrganization",
      "workmail:ListOrganizations",
      "xray:BatchGetTraces",
      "xray:GetTraceSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "datadog_aws_integration" {
  name   = "DatadogAWSIntegrationPolicy"
  policy = data.aws_iam_policy_document.datadog_aws_integration.json
}
resource "aws_iam_role" "datadog_aws_integration" {
  name               = "DatadogIntegrationRole"
  description        = "Role for Datadog AWS Integration"
  assume_role_policy = data.aws_iam_policy_document.datadog_aws_integration_assume_role.json
}
resource "aws_iam_role_policy_attachment" "datadog_aws_integration" {
  role       = aws_iam_role.datadog_aws_integration.name
  policy_arn = aws_iam_policy.datadog_aws_integration.arn
}
resource "aws_iam_role_policy_attachment" "datadog_aws_integration_security_audit" {
  role       = aws_iam_role.datadog_aws_integration.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "datadog_integration_aws_account" "datadog_integration" {
  account_tags   = []
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = "aws"
  aws_regions {
    include_all = true
  }
  auth_config {
    aws_auth_config_role {
      role_name = "DatadogIntegrationRole"
    }
  }
    resources_config {
    cloud_security_posture_management_collection = true
    extended_collection                          = true
  }
  traces_config {
    xray_services {
    }
  }
    logs_config {
    lambda_forwarder {
    }
  }
  metrics_config {
    namespace_filters {
    }
  }
}


data "archive_file" "zip_code" {
  type        = "zip"
  source_dir  = "${path.module}/src/"
  output_path = "${path.module}/build/lambda_function.zip"
}

# Custom OTel layer
resource "aws_lambda_layer_version" "otel_layer" {
  filename            = "otel-layer.zip"
  layer_name         = "otel-python-layer"
  compatible_runtimes = ["python3.13"]
  description        = "OpenTelemetry Python SDK for Lambda"
}

module "lambda-datadog" {
  source  = "DataDog/lambda-datadog/aws"
  version = "4.0.0"

  # aws_lambda_function arguments
  filename      = "${path.module}/build/lambda_function.zip"
  function_name = var.function_name
  handler       = var.lambda_handler 
  runtime       = var.runtime
  role          = aws_iam_role.lambda_exec_role.arn
  memory_size   = 256

  # Attach custom OTel layer
  layers = [aws_lambda_layer_version.otel_layer.arn]


  environment_variables = {
    DD_API_KEY_SECRET_ARN = aws_secretsmanager_secret.datadog_api_key_secret.arn
    DD_ENV                = "development"
    DD_SERVICE            = "my-service"
    DD_SITE               = var.datadog_site
    DD_VERSION            = "1.0.0"
    DD_TRACE_OTEL_ENABLED      = "true" #enables OTel
    DD_TRACE_PROPAGATION_STYLE = "tracecontext"
    DD_TRACE_DEBUG             = "true"
  }

  datadog_extension_layer_version = 86
  datadog_python_layer_version    = 114

  tags = {
    datadog_monitored = "true"
    env               = var.environment
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "my-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "datadog_api_key_secret" {
  name                    = "datadog-api-key-secret"
  description             = "Datadog API Key Secret"
  recovery_window_in_days = 0 # This ensures immediate deletion
  tags = {
    Name        = "datadog-api-key-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "datadog_api_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key_secret.id
  secret_string = var.datadog_api_key
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "datadog_secrets_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}

resource "aws_iam_policy" "secrets_manager_access" {
  name = "datadog-secrets-manager-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ],
        Effect   = "Allow",
        Resource = aws_secretsmanager_secret.datadog_api_key_secret.arn
      }
    ]
  })
}

# Output the function ARN for invocation/testing
output "lambda_arn" {
  value = module.lambda-datadog.arn
}

output "lambda_handler" {
  value = var.lambda_handler
}
```


### setup terraform code
- see `lambda-datadog.tf` 
- setup `terraform.tfvars` to pass variables including datadog api key and app key and apply `terraform apply -var-file="my_variables.tfvars"`
    ```sh
    # terraform.tfvars
    datadog_api_key = "xxx"
    datadog_app_key = "xxx"
    datadog_site    = "us5.datadoghq.com"
    environment     = "development"
    function_name   = "my-datadog-instrumented-lambda"
    runtime         = "python3.13"
    lambda_handler  = "datadog-instrumented-lambda-function.lambda_handler"
    ```
    - **alternative 1: Command-line Flags:** You can pass individual variable values directly on the command line using the -var flag. e.x. `terraform apply -var="instance_type=t2.micro" -var="region=us-east-1"`
    - **alternative 2: environment Variables:**Terraform checks for environment variables prefixed with TF_VAR_. e.x. `export TF_VAR_region="us-west-2"` then `terraform apply`

- make sure to specify `api_url` in datadog provider to stop 403 erros in tf plan:
    ```terraform
    provider "datadog" {
        api_key = var.datadog_api_key
        app_key = var.datadog_app_key
        api_url = "https://api.${var.datadog_site}/"
    }
    ```

### apply resources

```sh
# plan
terraform plan -var-file="terraform.tfvars" -out=myplan.tfplan
# apply
terraform apply "myplan.tfplan" 
```

### test lamda

In aws console the lambda handler is shown as `datadog_lambda.handler.handler`. This is not a cause for worry. Your code will still work fine.

invoke lambda by clicking on test button in lambda in aws console

. they should suceed:

```sh
{
  "statusCode": 200,
  "body": "\"Hello from instrumented Lambda!\""
}
```

### observe datadog for activity

go to https://us5.datadoghq.com/serverless/aws/lambda

observe: 
![](img/out01.png)
![](img/out02.png)
### destroy resources


# destroy

**Revoke your application and api keys from datadog or do not add them to git!**

```sh        
terraform destroy
```

### Do You Need datadog_integration_aws_account setup im terraform?
The datadog_integration_aws_account Terraform resource configures the Datadog-AWS integration, which enables Datadog to pull metrics, logs, and events from AWS services (e.g., EC2, S3, RDS, CloudWatch) via an IAM role. For Lambda-specific OTel instrumentation with the Datadog Lambda Extension, this integration is not strictly required for traces to flow, as the extension sends OTel spans directly to Datadog using the DD_API_KEY (or DD_API_KEY_SECRET_ARN) configured in the Lambda environment variables. However, there are scenarios where the integration is beneficial or necessary:
When You Need It

**Broader AWS Monitoring:** If your setup includes monitoring other AWS resources (e.g., API Gateway, DynamoDB, or SQS) alongside Lambda, the AWS integration allows Datadog to collect CloudWatch metrics, logs, or events for a holistic view. For example, to correlate Lambda traces with metrics from an upstream API Gateway, you need this integration.
Enhanced Serverless Metrics: While the Lambda Extension handles traces and basic Lambda metrics (e.g., invocations, durations), the AWS integration pulls additional CloudWatch metrics (e.g., detailed Lambda errors or throttling) into Datadog's Serverless view for richer dashboards.

**Log Collection:** If you want to forward Lambda CloudWatch Logs to Datadog (e.g., for debugging or log-based metrics), the integration is required to enable the Datadog Forwarder Lambda, which collects logs from CloudWatch Log Groups.
Automatic Tag Enrichment: The integration allows Datadog to automatically tag resources (e.g., by AWS region or account) for better filtering in the Datadog UI, which is useful for large-scale deployments.

#### When You Don’t Need It

- **Traces-Only Use Case**: If you're only sending OTel traces from your Lambda function to Datadog via the extension (as configured with DD_TRACE_OTEL_ENABLED=true and DD_API_KEY), the extension handles trace ingestion directly over HTTPS to Datadog's endpoint. No AWS integration is needed for this.
- **No Additional AWS Services**: If your monitoring is limited to Lambda traces and basic serverless metrics (provided by the extension), you can skip the integration.
- **Manual Log Handling**: If you don’t need Datadog to ingest CloudWatch Logs or prefer manual log analysis, the integration isn’t necessary.