provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 0.11.0"
}

# EXAMPLE: https://github.com/SebastianUA/terraform/tree/master/aws/modules/glue
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

variable "vpc-id" {
  default = "vpc-xxx"
}

variable "redshift-subnet-id" {
  default = "subnet-xxx"
}

//should match the az of rds 
variable "rds-subnet-id" {
  default = "subnet-xxx"
}

variable "redshift_sg" {
  default = "sg-xxx"
}

variable "rds_sg" {
  default = "sg-xxx"
}

variable "bucket_for_glue" {
  default = "dmrh-import-sensor-events-bucket"
}

variable "bucket_for_glue_scripts" {
  default = "dmrh-glue-scripts"
}

variable "bucket_for_glue_output" {
  default = "dmrh-glue-output"
}

data "aws_redshift_cluster" "test_cluster" {
  cluster_identifier = "redshift-cluster-1"
}

data "aws_db_instance" "rds" {
  db_instance_identifier = "genesis" # for aurora this is db cluster instsance id (DB instance id)
}

# data "aws_subnet" "glue_connect_ima_subnet" {
#   id = "${var.ima_cluster_subnet_id}"
# }


resource "aws_vpc_endpoint" "s3" {
  vpc_id       = "${var.vpc-id}"
  service_name = "com.amazonaws.us-east-1.s3"

  tags = {
    Environment = "test"
  }
}

resource "aws_iam_role" "aws_iam_glue_role" {
  name = "AWSGlueServiceRoleDefault"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role       = "${aws_iam_role.aws_iam_glue_role.id}"
}

//TODO : Limit to read access 
resource "aws_iam_role_policy_attachment" "glue_service_attachment_redshift" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess"
  role       = "${aws_iam_role.aws_iam_glue_role.id}"
}

resource "aws_iam_role_policy_attachment" "glue_service_attachment_rds" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRdsFullAccess"
  role       = "${aws_iam_role.aws_iam_glue_role.id}"
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = "${aws_iam_role.aws_iam_glue_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${var.bucket_for_glue_output}",
        "arn:aws:s3:::${var.bucket_for_glue_output}/*",
         "arn:aws:s3:::${var.bucket_for_glue_scripts}",
        "arn:aws:s3:::${var.bucket_for_glue_scripts}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "glue_service_s3" {
  name   = "glue_service_s3"
  role   = "${aws_iam_role.aws_iam_glue_role.id}"
  policy = "${aws_iam_role_policy.s3_policy.policy}"
}

resource "aws_glue_catalog_database" "glue_catalog_database" {
  name = "journey-catalog-database"
}

resource "aws_glue_connection" "glue_redshift_connection" {
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${data.aws_redshift_cluster.test_clustertest_cluster.database_name}"
    PASSWORD            = "testPassword1"
    USERNAME            = "awsuser"
  }

  name = "glue_redshift_connection"

  physical_connection_requirements {
    availability_zone      = "us-east-1f"
    # availability_zone = "${data.aws_subnet.glue_connect_ima_subnet.availability_zone}"
    security_group_id_list = ["${var.redshift_sg}"]
    subnet_id              = "${var.redshift-subnet-id}"
  }
}

resource "aws_glue_connection" "glue_rds_connection" {
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://${data.aws_db_instance.rds.endpoint}/genesis"
    PASSWORD            = "testPassword1"
    USERNAME            = "testUser"
  }

  name = "glue_rds_connection"
  //Note the rds connectionaz must match. if no choice given in rds config rdsreboot could changes this.
  physical_connection_requirements {
    availability_zone      = "us-east-1f" 
    security_group_id_list = ["${var.rds_sg}"]
    subnet_id              = "${var.rds-subnet-id}"
  }
}

# resource "aws_glue_classifier" "glue_classifier" {
#   name = "split-array-into-records"

#   json_classifier {
#     json_path = "$[*]"
#   }
# }

//https://stackoverflow.com/questions/58034202/how-to-run-aws-glue-crawler-after-resource-update-created
resource "aws_glue_crawler" "glue_redshift_crawler" {
  database_name = "${aws_glue_catalog_database.glue_catalog_database.name}"
  name          = "redshift-crawler"

  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
  role = "${aws_iam_role.aws_iam_glue_role.arn}"

  jdbc_target {
    connection_name = "${aws_glue_connection.glue_redshift_connection.name}"
    path            = "dev/dw/%"
  }

  provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name}"
  }
}

resource "aws_glue_crawler" "glue_rds_crawler" {
  database_name = "${aws_glue_catalog_database.glue_catalog_database.name}"
  name          = "rds-crawler"

  # classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
  role = "${aws_iam_role.aws_iam_glue_role.arn}"

  jdbc_target {
    connection_name = "${aws_glue_connection.glue_rds_connection.name}"
    path            = "genesis/public/%"
  }

  provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name}"
  }
}

//https://github.com/terraform-providers/terraform-provider-aws/issues/9524

resource "aws_glue_job" "hh_list" {
  name         = "hh_list"
  role_arn     = "${aws_iam_role.aws_iam_glue_role.arn}"
  connections  = ["${aws_glue_connection.glue_rds_connection.name}", "${aws_glue_connection.glue_redshift_connection.name}"]
  glue_version = "1.0"
  max_capacity = 2

  command {
    script_location = "s3://${var.bucket_for_glue_scripts}/workflow/get_hh_list.py"
  }

  default_arguments = {
    "--enable-metrics" = ""
    "--job-language"   = "python"
    "--TempDir"        = "${var.bucket_for_glue_scripts}/TEMP"
    "--HH_LIST_CSV_FILENAME" = "hh-list.csv"
    "--HH_LIST_CSV_BUCKET" = "${var.bucket_for_glue_output}"
    "--HH_LIST_CSV_BUCKET_PREFIX" = "hh_list"
  }
}

resource "aws_glue_job" "hh_metadata" {
  name         = "hh_metadata"
  role_arn     = "${aws_iam_role.aws_iam_glue_role.arn}"
  connections  = ["${aws_glue_connection.glue_rds_connection.name}", "${aws_glue_connection.glue_redshift_connection.name}"]
  glue_version = "1.0"
  max_capacity = 2

  command {
    script_location = "s3://${var.bucket_for_glue_scripts}/workflow/unload-hh-metadata.py"
  }

  default_arguments = {
    "--enable-metrics" = ""
    "--job-language"   = "python"
    "--TempDir"        = "s3://${var.bucket_for_glue_scripts}/TEMP"
    "--HH_LIST_CSV_FILENAME" = "hh-list.csv"
    "--HH_LIST_CSV_BUCKET" = "${var.bucket_for_glue_output}"
    "--HH_LIST_CSV_BUCKET_PREFIX" = "hh_list"
    "--HH_METADATA_CSV_FILENAME" = "hh-metadata.csv"
    "--HH_METADATA_CSV_BUCKET" = "${var.bucket_for_glue_output}"
    "--HH_METADATA_CSV_BUCKET_PREFIX" = "hh-metadata"
  }
}

resource "aws_glue_job" "member_hh_interactions" {
  name         = "member_hh_interactions"
  role_arn     = "${aws_iam_role.aws_iam_glue_role.arn}"
  connections  = ["${aws_glue_connection.glue_rds_connection.name}", "${aws_glue_connection.glue_redshift_connection.name}"]
  glue_version = "1.0"
  max_capacity = 2

  command {
    script_location = "s3://${var.bucket_for_glue_scripts}/workflow/unload-member-hh-interactions.py"
  }

  default_arguments = {
    "--enable-metrics" = ""
    "--job-language"   = "python"
    "--TempDir"        = "s3://${var.bucket_for_glue_scripts}/TEMP"
    "--HH_LIST_CSV_FILENAME" = "hh-list.csv"
    "--HH_LIST_CSV_BUCKET" = "${var.bucket_for_glue_output}"
    "--HH_LIST_CSV_BUCKET_PREFIX" = "hh_list"
    "--HH_MEMBER_INTERACTIONS_CSV_FILENAME" = "member-hh-interactions.csv"
    "--HH_MEMBER_INTERACTIONS_CSV_BUCKET" = "${var.bucket_for_glue_output}"
    "--HH_MEMBER_INTERACTIONS_CSV_BUCKET_PREFIX" = "member-hh-interactions"
  }
}

resource "aws_glue_workflow" "glue_workflow_train_data" {
  name = "glue_workflow_train_data"
}

resource "aws_glue_trigger" "glue_trigger_start_hh_list" {
  name = "glue_trigger_start_hh_list"

  # schedule = "cron(15 12 * * ? *)"
  # type     = "SCHEDULED"

  workflow_name = "${aws_glue_workflow.glue_workflow_train_data.name}"

  type = "ON_DEMAND"

  actions {
    job_name = "${aws_glue_job.hh_list.name}"
  }

  # actions = [
  #   {
  #       jobName = "journey-job"
  #   },
  #   {
  #     jobName = "hh-job-job"
  #   }
  # ]

  # //if type = "CONDITIONAL"
  # predicate {
  #   conditions {
  #     crawler_name = "${aws_glue_crawler.glue_rds_crawler.name}"
  #     crawl_state  = "SUCCEEDED"
  #   }

  #   conditions {
  #     crawler_name = "${aws_glue_crawler.glue_redshift_crawler.name}"
  #     crawl_state  = "SUCCEEDED"
  #   }

  #   logical = "AND"
  # }
}

resource "aws_glue_trigger" "glue_trigger_hh_metadata" {
  name          = "glue_trigger_hh_metadata"
  type          = "CONDITIONAL"
  workflow_name = "${aws_glue_workflow.glue_workflow_train_data.name}"

  predicate {
    conditions {
      job_name = "${aws_glue_job.hh_list.name}"
      state    = "SUCCEEDED"
    }
  }

  actions {
    job_name = "${aws_glue_job.hh_metadata.name}"
  }
}

resource "aws_glue_trigger" "glue_trigger_start_member_hh_interactions" {
  name          = "glue_trigger_start_member_hh_interactions"
  type          = "CONDITIONAL"
  workflow_name = "${aws_glue_workflow.glue_workflow_train_data.name}"

  predicate {
    conditions {
      job_name = "${aws_glue_job.hh_metadata.name}"
      state    = "SUCCEEDED"
    }
  }

  actions {
    job_name = "${aws_glue_job.member_hh_interactions.name}"
  }
}

# https://aws.amazon.com/premiumsupport/knowledge-center/cloudwatch-create-custom-event-pattern/
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/CloudWatchEventsandEventPatterns.html
# resource "aws_cloudwatch_event_rule" "worflow_trigger_lambda" {
#   name = "calculator"
#   schedule_expression = "rate(1 minute)"
# }

# resource "aws_cloudwatch_event_target" "health_monitor_event_target" {
#   rule = aws_cloudwatch_event_rule.calculator.id
#   arn = aws_sfn_state_machine.calculator-state-machine.id
#   role_arn = aws_iam_role.iam_for_sfn.arn
#   input = <<EOF
#   {
#   "operand1": "3",
#   "operand2": "5",
#   "operator": "add"
#   }
# EOF
# }