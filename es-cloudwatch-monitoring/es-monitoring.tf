// prerequisites: 
// export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_FOR_DEV"
// export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY_FOR_DEV"

provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 0.11.0"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


// ELASTICSEARCH (with my ip to access)
variable "domain" {
  default = "audience"
}


variable "has_cloudwatch" {
  description = "enable/disable cloudwatch defaults to enabled"
  default     = true
}

variable "free_storage_space_threshold" {
  description = "The minimum amount of available storage space in MegaByte."
  default     = 32768
}

variable "min_available_nodes" {
  description = "The minimum available (reachable) nodes to have"
  default     = 3
}

variable "cpu_utilization_threshold" {
  description = "The maximum percentage of CPU utilization"
  default     = 80
}

variable "jvm_memory_pressure_threshold" {
  description = "The maximum percentage of the Java heap used for all data nodes in the cluster"
  default     = 80
}

variable "disk_queue_depth_too_high_threshold" {
  description = "The maximum depth of disk queue"
  default     = 64
}


variable "sre_cloudwatch_alert_topic" {
  name = "es_topic"
}

resource "aws_elasticsearch_domain" "example" {
  domain_name = "${var.domain}"
  elasticsearch_version = "6.4"

  cluster_config {
    instance_type = "t2.small.elasticsearch"
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


resource "aws_cloudwatch_metric_alarm" "elasticsearch_cluster_status_is_red" {
  count               = "${var.has_cloudwatch ? 1: 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_cluster_status_is_red"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Average elasticsearch cluster status is in red over last 1 minutes"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]
  treat_missing_data  = "ignore"

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_cluster_status_is_yellow" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_cluster_status_is_yellow"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.yellow"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Average elasticsearch cluster status is in yellow over last 1 minutes"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]
  treat_missing_data  = "ignore"

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_cluster_free_storage_space_too_low" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_cluster_free_storage_space_too_low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "${var.free_storage_space_threshold}"
  alarm_description   = "Average elasticsearch free storage space over last 1 minutes is too low"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]
  treat_missing_data  = "ignore"

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_cluster_index_writes_blocked" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_cluster_index_writes_blocked"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterIndexWritesBlocked"
  namespace           = "AWS/ES"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Elasticsearch index writes being blocker over last 5 minutes"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]
  treat_missing_data  = "ignore"

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_insufficient_available_nodes" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_insufficient_available_nodes"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Nodes"
  namespace           = "AWS/ES"
  period              = "86400"
  statistic           = "Minimum"
  threshold           = "${var.min_available_nodes}"
  alarm_description   = "Elasticsearch nodes minimum < ${var.min_available_nodes} for 1 day"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]
  treat_missing_data  = "ignore"

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_automated_snapshot_failure" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_automated_snapshot_failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "AutomatedSnapshotFailure"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Elasticsearch automated snapshot failed over last 1 minutes"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]
  treat_missing_data  = "ignore"

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_cpu_utilization_too_high" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_cpu_utilization_too_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = "900"
  statistic           = "Average"
  threshold           = "${var.cpu_utilization_threshold}"
  alarm_description   = "Average elasticsearch cluster CPU utilization over last 45 minutes too high"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_jvm_memory_pressure_too_high" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_jvm_memory_pressure_too_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "JVMMemoryPressure"
  namespace           = "AWS/ES"
  period              = "900"
  statistic           = "Maximum"
  threshold           = "${var.jvm_memory_pressure_threshold}"
  alarm_description   = "Elasticsearch JVM memory pressure is too high over last 15 minutes"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_disk_queue_depth_too_high" {
  count               = "${var.has_cloudwatch ? 1 : 0}"
  alarm_name          = "${lower(var.environment_tag)}_${var.domain}_elasticsearch_disk_queue_depth_too_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/ES"
  period              = "900"
  statistic           = "Maximum"
  threshold           = "${var.disk_queue_depth_too_high_threshold}"
  alarm_description   = "Elasticsearch disk queue depth is too high over last 15 minutes"
  alarm_actions       = ["${var.sre_cloudwatch_alert_topic}"]
  ok_actions          = ["${var.sre_cloudwatch_alert_topic}"]

  dimensions = {
    DomainName = "${var.domain}"
    ClientId   = "${data.aws_caller_identity.current.account_id}"
  }
}



