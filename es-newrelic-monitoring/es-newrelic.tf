provider "newrelic" {
  api_key = "${var.newrelic_api_key}"
}

provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 0.11.0"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

// ELASTICSEARCH
variable "domain" {
  default = "audience"
}

variable "newrelic_api_key" {
  default = "xxx"
}

resource "aws_elasticsearch_domain" "example" {
  domain_name           = "${var.domain}"
  elasticsearch_version = "6.4"

  cluster_config {
    instance_type = "t2.small.elasticsearch"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  tags = {
    Domain = "TestDomain"
  }

  access_policies = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "es:*",
      "Principal": "*",
      "Effect": "Allow",
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.domain}/*"
    }
  ]
}
POLICY
}

resource "newrelic_alert_policy" "red_status_alert_policy" {
  name = "red_status_alert_policy"
}

resource "newrelic_infra_alert_condition" "cluster_status_red" {
  policy_id = "${newrelic_alert_policy.red_status_alert_policy.id}"

  name                 = "Cluster status red"
  type                 = "infra_metric"
  integration_provider = "ElasticsearchCluster"
  select               = "provider.ClusterStatus.green.Maximum"
  comparison           = "equal"
  where                = "(`provider.domainName` LIKE '%audience%')"

  critical {
    duration      = 5
    value         = 1
    time_function = "all"
  }
}

resource "newrelic_infra_alert_condition" "cluster_free_storage_space_too_low" {
  policy_id = "${newrelic_alert_policy.red_status_alert_policy.id}"

  name                 = "elasticsearch_cluster_free_storage_space_too_low"
  type                 = "infra_metric"
  integration_provider = "ElasticsearchCluster"
  select               = "provider.FreeStorageSpace.Minimum"
  comparison           = "below"
  where                = "(`provider.domainName` LIKE '%audience%')"

  critical {
    duration      = 5
    value         = 6000
    time_function = "all"
  }
}

# Notification channel
resource "newrelic_alert_channel" "alert_notification_email" {
  name = "dmrhimali@gmail.com"
  type = "email"

  config {
    recipients              = "dmrhimali@gmail.com"
    include_json_attachment = "1"
  }
}

# Link the above notification channel to your policy
resource "newrelic_alert_policy_channel" "alert_policy_email" {
  policy_id = "${newrelic_alert_policy.red_status_alert_policy.id}"

  channel_ids = [
    "${newrelic_alert_channel.alert_notification_email.id}",
  ]
}
