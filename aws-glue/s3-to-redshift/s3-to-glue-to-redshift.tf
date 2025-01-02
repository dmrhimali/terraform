provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 0.11.0"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

// ELASTICSEARCH
variable "vpc-id" {
  default = "vpc-0bd9eada5fa059750"
}

variable "redshift-subnet-id" {
  default = "subnet-0f47c64f7b7252af0"
}

variable "redshift_sg" {
  default = "sg-0b02dae5114ff8758"
}

variable "bucket_for_glue" {
  default = "dmrh-import-sensor-events-bucket"
}

variable "bucket_for_glue_data" {
  default = "dmrh-import-sensor-events-bucket"
}

variable "bucket_for_glue_scripts" {
  default = "dmrh-glue-scripts"
}

variable "job_name" {
  default = "glue_job"
}

data "aws_redshift_cluster" "test_cluster" {
  cluster_identifier = "redshift-cluster-1"
}

# resource "aws_security_group" "redshift-sg" {
#   name        = "redshift-sg"
#   description = "controls access to Redshift"
#   vpc_id      = "${var.vpc-id}"

#   ingress {
#     protocol    = "${var.app_protocol}"
#     from_port   = "${var.app_port}"
#     to_port     = "${var.app_port}"
#     cidr_blocks = ["${split(",", var.cidr_blocks)}"]
#     security_groups = ["${data.aws_security_group.redshift-sg.id}"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#     security_groups = ["${data.aws_security_group.redshift-sg.id}"]
#   }
# }

# resource "aws_redshift_cluster" "redshift_cluster" {
#   cluster_identifier        = "redshift-cluster-1"
#   database_name             = "dev"
#   master_username           = "awsuser"
#   master_password           = "testPassword1"
#   node_type                 = "dc1.large"
#   cluster_type              = "single-node"
#   vpc_security_group_ids    = ["${aws_security_group.dummy.id}"]
#   cluster_subnet_group_name = "dummy-subnet-group"
#   encrypted                 = "false"
#   publicly_accessible       = "false"
# }

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
        "arn:aws:s3:::${var.bucket_for_glue_data}",
        "arn:aws:s3:::${var.bucket_for_glue_data}/*",
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
  name = "catalog-database"
}

resource "aws_glue_classifier" "glue_classifier" {
  name = "split-array-into-records"

  json_classifier {
    json_path = "$[*]"
  }
}

//https://stackoverflow.com/questions/58034202/how-to-run-aws-glue-crawler-after-resource-update-created
resource "aws_glue_crawler" "glue_crawler" {
  database_name = "${aws_glue_catalog_database.glue_catalog_database.name}"
  name          = "crawler"
  classifiers   = ["${aws_glue_classifier.glue_classifier.name}"]
  role          = "${aws_iam_role.aws_iam_glue_role.arn}"

  s3_target {
    path = "s3://${var.bucket_for_glue_data}/"
  }

    provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name}"
  }
}

//https://github.com/terraform-providers/terraform-provider-aws/issues/9524
resource "aws_glue_job" "glue_job" {
  name         = "${var.job_name}"
  role_arn     = "${aws_iam_role.aws_iam_glue_role.arn}"
  connections  = ["${aws_glue_connection.glue_redshift_connection.name}"]
  glue_version = "1.0"

  command {
    script_location = "s3://${var.bucket_for_glue_scripts}/tf/etl.py"
  }

  default_arguments = {
    "--enable-metrics" = ""
    "--job-language"   = "python"
    "--TempDir"        = "s3://${var.bucket_for_glue_scripts}/TEMP"
  }

  #   # Manually set python 3 and glue 1.0
  #   provisioner "local-exec" {
  #     command = "aws glue update-job --job-name ${var.job_name} --job-update 'Command={ScriptLocation=s3://${var.bucket_for_glue_scripts}/etl.py},PythonVersion=3,Name=glueetl},GlueVersion=1.0,Role=${aws_iam_role.aws_iam_glue_role.arn},DefaultArguments={--enable-metrics=\"\",--job-language=python,--TempDir=\"s3://${var.bucket_for_glue_scripts}/TEMP\"}'"
  #   }
}

resource "aws_glue_connection" "glue_redshift_connection" {
  connection_type = "JDBC"

  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${data.aws_redshift_cluster.test_cluster.endpoint}:5439/dev"
    PASSWORD            = "testPassword1"
    USERNAME            = "awsuser"
  }

  name = "glue_redshift_connection"

  physical_connection_requirements {
    availability_zone      = "us-east-1f"
    security_group_id_list = ["${var.redshift_sg}"]
    subnet_id              = "${var.redshift-subnet-id}"
  }
}
