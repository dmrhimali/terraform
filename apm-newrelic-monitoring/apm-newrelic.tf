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

variable "newrelic_api_key" {
  default = "xxx"
}
data "newrelic_application" "money_transfer_application" {
  name = "Money Transfer Application"
}

resource "newrelic_alert_policy" "money_transfer_application_policy" {
  name = "money_transfer_application_policy"
}

resource "newrelic_alert_condition" "money_transfer_application_alert_condition" {
  policy_id = "${newrelic_alert_policy.money_transfer_application_policy.id}"

  name            = "money_transfer_application_alert_condition"
  type            = "apm_app_metric"
  entities        = ["${data.newrelic_application.money_transfer_application.id}"]
  metric          = "apdex"
  condition_scope = "application"

  term {
    duration      = 5
    operator      = "below"
    priority      = "critical"
    threshold     = "0.75"
    time_function = "all"
  }
}

resource "newrelic_alert_channel" "money_transfer_application_alert_notification_email" {
  name = "dmrhimali@gmail.com"
  type = "email"

  config {
    recipients              = "dmrhimali@gmail.com"
    include_json_attachment = "1"
  }
}

# Link the above notification channel to your policy
resource "newrelic_alert_policy_channel" "alert_policy_email" {
  policy_id = "${newrelic_alert_policy.money_transfer_application_policy.id}"

  channel_ids = [
    "${newrelic_alert_channel.money_transfer_application_alert_notification_email.id}",
  ]
}


resource "newrelic_dashboard" "exampledash" {
  title = "money_transfer_application_dashboard"

  filter {
    event_types = [
        "Transaction"
    ]
    attributes = [
        "appName",
        "name"
    ]
  }

  widget {
    title = "Requests per minute"
    visualization = "billboard"
    nrql = "SELECT rate(count(*), 1 minute) FROM Transaction"
    row = 1
    column = 1
  }

  widget {
    title = "Error rate"
    visualization = "gauge"
    nrql = "SELECT percentage(count(*), WHERE error IS True) FROM Transaction"
    threshold_red = 2.5
    row = 1
    column = 2
  }

  widget {
    title = "Average transaction duration, by application"
    visualization = "facet_bar_chart"
    nrql = "SELECT average(duration) FROM Transaction FACET appName"
    row = 1
    column = 3
  }

  widget {
    title         = "Average Transaction Duration"
    row           = 1
    column        = 1
    width         = 2
    visualization = "faceted_line_chart"
    nrql          = "SELECT AVERAGE(duration) from Transaction FACET appName TIMESERIES auto"
  }
  
  widget {
    title = "Apdex, top 5 by host"
    duration = 1800000
    visualization = "metric_line_chart"
    entity_ids = [
      "${data.newrelic_application.money_transfer_application.id}",
    ]
    metric {
        name = "Apdex"
        values = [ "score" ]
    }
    facet = "host"
    limit = 5
    row = 2
    column = 1
  }

  widget {
    title = "Requests per minute, by transaction"
    visualization = "facet_table"
    nrql = "SELECT rate(count(*), 1 minute) FROM Transaction FACET name"
    row = 2
    column = 2
  }

  widget {
    title = "Dashboard Note"
    visualization = "markdown"
    source = "### Helpful Links\n\n* [New Relic One](https://one.newrelic.com)\n* [Developer Portal](https://developer.newrelic.com)"
    row = 2
    column = 3
  }

}