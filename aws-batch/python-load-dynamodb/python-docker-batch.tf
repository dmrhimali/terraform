provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 0.11.0"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

variable "environment_tag" {
    default="personal"
}

variable "vpc_id" {
    default="vpc-xxx"
}

variable "batch_compute_environment_name" {
  default = "compute-environment"
}

variable "batch_compute_environment_instance_type" {
  default = "optimal"
}

variable "batch_compute_environment_type" {
  default = "MANAGED"
}

variable "batch_compute_environment_compute_resource_type" {
  default = "EC2"
}
variable "batch_compute_environment_max_vcpus" {
  default = 16
}

variable "batch_compute_environment_min_vcpus" {
  default = 0
}

variable "batch_compute_environment_desired_vcpus" {
  default = 4
}

variable "batch_compute_environment_allocation_stratergy" {
  default = "BEST_FIT"
}

variable "batch_compute_environment_image_ami_id" {
    default="ami-0e2ff28bfb72a4e45"
}


variable "ec2_key_name" {
    default="myi_keypair"
}

variable "aws_batch_job_queue_state" {
  default = "ENABLED"
}

variable "aws_batch_job_queue_priority" {
  default = "300"
}

variable "ecr_image_tag" {
  default = "latest"
}

variable "batch_job_definition_container_memory" {
  default = 2000
}

variable "batch_job_definition_container_vcpus" {
  default = 4
}

variable "batch_job_definition_container_attempts" {
  default = 1
}

data "aws_subnet_ids" "app-subnet-ids" {
  vpc_id = "${var.vpc_id}"

}

locals {
  ecr_image_repo = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/dmrh/aws-batch-demo"
}

resource "aws_security_group" "batch-compute-environment-sg" {
  name        = "${lower(var.environment_tag)}-batch-compute-environment-sg"
  description = "Security group for app service  batch compute environment"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${lower(var.environment_tag)}-app-service-batch-compute-environment-sg"
    environment = "${lower(var.environment_tag)}"a
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${lower(var.environment_tag)}-ecs-instance-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "ec2.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = "${aws_iam_role.ecs_instance_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_role" {
  name = "${lower(var.environment_tag)}-ecs_instance_role"
  role = "${aws_iam_role.ecs_instance_role.name}"
}

resource "aws_iam_role" "aws_batch_service_role" {
  name = "${lower(var.environment_tag)}-aws-batch-service-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "batch.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = "${aws_iam_role.aws_batch_service_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_iam_role" "batch_job_role" {
  name = "${lower(var.environment_tag)}-replay-aws-batch-job-role"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
        }
    }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "batch_job_role_dynamodb_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = "${aws_iam_role.batch_job_role.name}"
}



resource "aws_batch_compute_environment" "batch_compute_environment" {
//  compute_environment_name = "${lower(var.environment_tag)}-${var.batch_compute_environment_name}"

  #workaround for known issue: https://github.com/terraform-providers/terraform-provider-aws/issues/11077
  compute_environment_name_prefix = "${lower(var.environment_tag)}-${var.batch_compute_environment_name}"

  compute_resources {
    allocation_strategy = "${var.batch_compute_environment_allocation_stratergy}"
    ec2_key_pair       = "${var.ec2_key_name}"
    //image_id           = "${var.batch_compute_environment_image_ami_id}"
    instance_role      = "${aws_iam_instance_profile.ecs_instance_role.arn}"
    instance_type      = ["${var.batch_compute_environment_instance_type}"]
    max_vcpus          = "${var.batch_compute_environment_max_vcpus}"
    min_vcpus          = "${var.batch_compute_environment_min_vcpus}"
    desired_vcpus      = "${var.batch_compute_environment_desired_vcpus}"
    //security_group_ids = ["${data.aws_security_group.batch_compute_environment_sg.id}"]
    security_group_ids = ["${aws_security_group.batch-compute-environment-sg.id}"]
    subnets            = ["${data.aws_subnet_ids.app-subnet-ids.ids}"]
    type               = "${var.batch_compute_environment_compute_resource_type}"

    tags {
      Name        = "${lower(var.environment_tag)}-${var.batch_compute_environment_name}"
      environment = "${lower(var.environment_tag)}"
    }
  }


  lifecycle {
    create_before_destroy = true
  }

  service_role = "${aws_iam_role.aws_batch_service_role.arn}"
  type         = "${var.batch_compute_environment_type}"
  depends_on   = ["aws_iam_role_policy_attachment.aws_batch_service_role"]
}

resource "aws_batch_job_queue" "batch_job_queue" {
  name     = "${lower(var.environment_tag)}-batch-job-queue"
  state    = "${var.aws_batch_job_queue_state}"
  priority = "${var.aws_batch_job_queue_priority}"

  compute_environments = [
    "${aws_batch_compute_environment.batch_compute_environment.arn}",
  ]
}

resource "aws_batch_job_definition" "batch_job_definition" {
  name = "${lower(var.environment_tag)}-batch-job-definition"
  type = "container"

#   parameters = {
#     sourceName      = "none"
#     eventEndDate    = "none"
#     streamEndDate   = "none"
#     eventType       = "none"
#     streamStartDate = "none"
#     streamName      = "none"
#     eventStartDate  = "none"
#   }

  retry_strategy = {
    attempts = 1
  }

  //  lifecycle {
  //    ignore_changes = ["container_properties"]
  //  }

  container_properties = <<CONTAINER_PROPERTIES
{
    "image": "${local.ecr_image_repo}:${var.ecr_image_tag}",
    "memory": ${var.batch_job_definition_container_memory},
    "vcpus": ${var.batch_job_definition_container_vcpus},
    "attempts": ${var.batch_job_definition_container_attempts},
    "jobRoleArn": "${aws_iam_role.batch_job_role.arn}",
    "environment": []
}
CONTAINER_PROPERTIES
#   timeout = {
#     attempt_duration_seconds = 60
#   }
  //depends_on = ["aws_ecr_repository.ecr_repository"]
}
 

 resource "aws_iam_role" "batch_job_submit_role" {
  name = "${lower(var.environment_tag)}-aws-batch-job-submit-role"

  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "events.amazonaws.com"
        }
    }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "batch_job_submit_role_policy_attachment" {
  policy_arn = "${aws_iam_policy.batch_job_submit_role_policy.arn}"
  role       = "${aws_iam_role.batch_job_submit_role.name}"
}
resource "aws_iam_policy" "batch_job_submit_role_policy" {
  policy = "${data.aws_iam_policy_document.batch_submit_job_role_document.json}"
}

data "aws_iam_policy_document" "batch_submit_job_role_document" {
  statement {
    sid    = "AlowBatchSubmitJob"
    effect = "Allow"

    resources = [
      "*",
    ]

    actions = [
      "batch:SubmitJob",
    ]
  }
}
 resource "aws_cloudwatch_event_target" "scheduled-job" {
  target_id = "batch-queue"
  rule      = "${aws_cloudwatch_event_rule.test_rule.name}"
  arn       = "${aws_batch_job_queue.batch_job_queue.arn}"
  role_arn  = "${aws_iam_role.batch_job_submit_role.arn}"
  batch_target {
    job_name       = "batch-job"
    job_definition = "${aws_batch_job_definition.batch_job_definition.id}"
  }

}

//run batch job every five minutes
resource "aws_cloudwatch_event_rule" "test_rule" {
  name                = "example-cw-rule"
  description         = "Cron job to update data"
  schedule_expression = "cron(0/5 * * * ? *)"
}

//run batch job nightly at 2:30
resource "aws_cloudwatch_event_rule" "test_rule" {
  name                = "example-cw-rule"
  description         = "Cron job to update data"
  schedule_expression = "cron(30 2 * * ? *)"
}