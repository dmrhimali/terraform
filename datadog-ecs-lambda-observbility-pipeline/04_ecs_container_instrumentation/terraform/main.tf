terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Change as needed
}

# Data sources for defaults
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# IAM Role for ECS Task Execution (logs, ECR pull)
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_ssm_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# IAM Task Role for ECS Tasks
data "aws_iam_policy_document" "ecs_task_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_role_policy.json
}

# Attach SSM permissions to the task role
resource "aws_iam_role_policy_attachment" "ecs_task_role_ssm_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# Default VPC and Subnets
resource "aws_default_vpc" "default_vpc" {}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-east-1b"
}

# ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name = "python-ecs-app"
  force_delete = true
}

# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "python-ecs-cluster"
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_default_vpc.default_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_default_vpc.default_vpc.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "python-ecs-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id]
}

resource "aws_lb_target_group" "app_tg" {
  name        = "python-ecs-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ECS Task Definition (Fargate + Datadog Sidecar)
resource "aws_ecs_task_definition" "app_task" {
  family                   = "python-ecs-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    # App Container
    {
      name  = "python-app"
      image = "${aws_ecr_repository.app_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/python-app"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "DD_API_KEY", value = var.datadog_api_key },
        { name = "DD_TRACE_AGENT_URL", value = "http://localhost:8126" },  # Point to sidecar
        { name = "DD_SERVICE", value = "python-flask" },
        { name = "DD_ENV", value = "prod" },
        { name = "DD_VERSION", value = "1.0.0" }
      ]
    },
    # Datadog Agent Sidecar
    {
      name  = "datadog-agent"
      image = "gcr.io/datadoghq/agent:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8126  # APM traces
          protocol      = "tcp"
        },
        {
          containerPort = 8125  # DogStatsD metrics
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/datadog-agent"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "DD_API_KEY", value = var.datadog_api_key },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_LOGS_ENABLED", value = "true" },
        { name = "DD_LOGS_CONFIG_USE_HTTP", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
        { name = "DD_SITE", value = "us5.datadoghq.com" },  # Or your DD site
        { name = "DD_CONTAINER_INCLUDE_LOGS", value = "name:python-app" }  # Collect app logs
      ]
      ulimits = [
        {
          name = "nofile"
          softLimit = 65535
          hardLimit = 65535
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "python-ecs-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true  # Add this line

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "python-app"
    container_port   = 8000
  }

  network_configuration {
    subnets          = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/python-app"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "agent_logs" {
  name              = "/ecs/datadog-agent"
  retention_in_days = 7
}

resource "null_resource" "build_push_image" {
  triggers = {
    image_tag = "latest"
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com
      docker build -t ${aws_ecr_repository.app_repo.repository_url}:latest ../
      docker push ${aws_ecr_repository.app_repo.repository_url}:latest
    EOT
  }

  depends_on = [aws_ecr_repository.app_repo]
}

data "aws_caller_identity" "current" {}


# Output ALB DNS
output "app_url" {
  value = aws_lb.app_alb.dns_name
}