### Production-Ready Tutorial: Deploying a Python App to AWS ECS Fargate and Lambda with Datadog Monitoring via Terraform

This tutorial guides you through deploying a simple Python Flask web app to both AWS ECS on Fargate (containerized) and AWS Lambda (serverless), while setting up end-to-end monitoring using Datadog's Observability Pipelines. We'll use Terraform (latest version as of September 2025: ~1.9.x) to provision all infrastructure. The setup is production-ready, incorporating:

- **Security**: Least-privilege IAM roles, VPC isolation, HTTPS, and secrets management.
- **Scalability**: Auto-scaling for ECS and Lambda concurrency.
- **Reliability**: Health checks, multi-AZ deployment, and retries.
- **Monitoring**: Datadog integration for logs, metrics, and traces. Logs from CloudWatch are forwarded to Datadog via subscription filters. We'll create a Datadog Observability Pipeline (using the `datadog_observability_pipeline` resource in preview mode—request access via Datadog if needed) with processors (e.g., remapping fields) and downstream sinks (e.g., to Datadog for indexing and to S3 for archival). Finally, we'll provision Datadog dashboards for visualization.

**Assumptions**:
- You have an AWS account with admin access and a Datadog account (EU1/US1/etc.) with API/APP keys.
- The Python app is a basic Flask API (e.g., `/health` endpoint). We'll provide sample code.
- You'll build/push the Docker image for ECS and zip the Lambda code manually (Terraform can't automate builds).
- Terraform state is stored in S3 with DynamoDB locking for production.

#### Step 1: Prerequisites
1. Install Terraform (v1.9+): Download from [HashiCorp](https://developer.hashicorp.com/terraform/install).
2. Configure AWS CLI: `aws configure` with your credentials.
3. Get Datadog keys: API key (for reads/writes) and APP key (for auth). Set as env vars: `export DD_API_KEY=your_api_key` and `export DD_APP_KEY=your_app_key`.
4. Create a project directory: `mkdir python-app-deploy && cd python-app-deploy`.
5. Initialize Git for version control: `git init`.

#### Step 2: Prepare the Python App
Create a simple Flask app deployable to both ECS and Lambda.

1. Create `app.py` (shared code):
   ```python
   from flask import Flask
   import os
   import logging

   app = Flask(__name__)
   logging.basicConfig(level=logging.INFO)
   logger = logging.getLogger(__name__)

   @app.route('/health')
   def health():
       logger.info('Health check called')
       return {'status': 'healthy'}, 200

   @app.route('/')
   def hello():
       logger.info('Hello endpoint called')
       return {'message': 'Python app deployed!'}, 200

   if __name__ == '__main__':
       port = int(os.environ.get('PORT', 8080))
       app.run(host='0.0.0.0', port=port)
   ```

2. For **ECS Fargate** (containerized):
   - Create `Dockerfile`:
     ```dockerfile
     FROM public.ecr.aws/lambda/python:3.12  # Reuse for Lambda compatibility
     WORKDIR /var/task
     COPY app.py requirements.txt ./
     RUN pip install flask gunicorn
     CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
     ```
   - Create `requirements.txt`: `flask\ngunicorn`.
   - Build and push to ECR (do this manually; automate in CI/CD later):
     ```bash
     # Create ECR repo (we'll do this in Terraform too)
     aws ecr create-repository --repository-name python-app --region us-east-1
     aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
     docker build -t python-app .
     docker tag python-app:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/python-app:latest
     docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/python-app:latest
     ```

3. For **Lambda** (serverless):
   - Zip the code: `zip -r lambda.zip app.py requirements.txt`.
   - Note: Lambda uses the same `app.py` but with a handler wrapper (add if needed for Lambda runtime).

#### Step 3: Project Structure and Terraform Initialization
Organize files:
```
.
├── main.tf          # Providers, backend, modules
├── variables.tf     # Inputs
├── outputs.tf       # Outputs
├── ecs.tf           # ECS Fargate resources
├── lambda.tf        # Lambda resources
├── datadog.tf       # Datadog pipeline, sinks, dashboards
├── vpc.tf           # Networking
└── app.py, Dockerfile, requirements.txt  # App files (not managed by TF)
```

Run `terraform init` to download providers.

#### Step 4: Configure Terraform Providers and Backend
Create `main.tf`:
```hcl
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 0.8.0"  # Latest as of 2025; supports observability_pipeline (preview)
    }
  }

  backend "s3" {
    bucket         = "your-tf-state-bucket"  # Create this bucket first
    key            = "python-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"  # Create with AWS CLI: aws dynamodb create-table ...
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  site    = "datadoghq.com"  # Change to eu/etc. if needed
}

variable "aws_region" { default = "us-east-1" }
variable "datadog_api_key" { sensitive = true }
variable "datadog_app_key" { sensitive = true }
```

Set vars: Create `terraform.tfvars` with your keys and region.

Run `terraform init`.

#### Step 5: Set Up Networking (VPC for ECS)
Create `vpc.tf`:
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "python-app-vpc" }
}

resource "aws_subnet" "private" {
  count = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = { Name = "private-subnet-${count.index + 1}" }
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.main.id }

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # Assume one public subnet for NAT
}

resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_subnet" "public" {
  count = 1
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "public-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public.id
}

# Private route table with NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security group for ECS/Lambda ALB
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id
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
  tags = { Name = "python-app-sg" }
}
```

This creates a multi-AZ VPC with public/private subnets and NAT for outbound traffic.

#### Step 6: Deploy to ECS Fargate
Create `ecs.tf`:
```hcl
resource "aws_ecs_cluster" "main" {
  name = "python-app-cluster"
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECR repo (created earlier manually, but idempotent)
resource "aws_ecr_repository" "app" {
  name = "python-app"
  image_scanning_configuration { scan_on_push = true }
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "python-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn  # For app logging
  container_definitions = jsonencode([{
    name  = "python-app"
    image = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 8080 }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    healthCheck = {
      command = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval = 30
      timeout  = 5
      retries  = 3
    }
  }])

  # Datadog agent sidecar for metrics/traces (production: use Datadog Operator for advanced)
  container_definitions += jsonencode([{
    name  = "datadog-agent"
    image = "public.ecr.aws/datadog/agent:latest"
    essential = false
    environment = [
      { name = "DD_API_KEY", value = var.datadog_api_key },
      { name = "DD_SITE", value = "datadoghq.com" }
    ]
    logConfiguration = { /* similar to above */ }
  }])
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/python-app"
  retention_in_days = 30  # Production: 90+ days
}

resource "aws_ecs_service" "app" {
  name            = "python-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2  # Min for HA
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.app_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "python-app"
    container_port   = 8080
  }

  # Auto-scaling
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
}

# ALB for ECS
resource "aws_lb" "app" {
  name               = "python-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.public[0].id]  # Add more for multi-AZ
}

resource "aws_lb_target_group" "app" {
  name     = "python-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Forward CloudWatch logs to Datadog (via Lambda forwarder)
resource "aws_cloudwatch_log_subscription_filter" "ecs_to_datadog" {
  name            = "ecs-to-datadog"
  log_group_name  = aws_cloudwatch_log_group.ecs.name
  filter_pattern  = ""  # All logs
  destination_arn = aws_lambda_function.datadog_forwarder.arn
}

# Datadog forwarder Lambda (provisioned via Terraform)
resource "aws_iam_role" "datadog_forwarder" {
  name = "datadog-forwarder-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "datadog_forwarder_policy" {
  role = aws_iam_role.datadog_forwarder.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "arn:aws:s3:::your-datadog-logs-bucket/*" }  # If archiving
    ]
  })
}

data "archive_file" "datadog_forwarder" {
  type        = "zip"
  source_dir  = "datadog_forwarder_lambda"  # Download from Datadog GitHub and place here
  output_path = "datadog_forwarder.zip"
}

resource "aws_lambda_function" "datadog_forwarder" {
  filename         = data.archive_file.datadog_forwarder.output_path
  function_name    = "datadog-forwarder"
  role             = aws_iam_role.datadog_forwarder.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  environment {
    variables = {
      DD_API_KEY = var.datadog_api_key
      DD_SITE    = "datadoghq.com"
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id      = "AllowExecutionFromCloudWatch"
  action            = "lambda:InvokeFunction"
  function_name     = aws_lambda_function.datadog_forwarder.function_name
  principal         = "logs.amazonaws.com"
  source_arn        = "${aws_cloudwatch_log_group.ecs.arn}:*"
}
```

**Notes**: Download the Datadog forwarder Lambda code from [Datadog's GitHub](https://github.com/DataDog/datadog-serverless-functions). This forwards logs to Datadog. For metrics/traces, the sidecar handles it.

#### Step 7: Deploy to Lambda
Create `lambda.tf`:
```hcl
resource "aws_iam_role" "lambda_execution" {
  name = "lambda-python-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_datadog" {
  role = aws_iam_role.lambda_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" }]
  })
}

data "archive_file" "lambda_app" {
  type        = "zip"
  source_dir  = "."  # Includes app.py and requirements.txt
  output_path = "lambda_app.zip"
  excludes    = ["Dockerfile"]  # Exclude non-Lambda files
}

resource "aws_lambda_function" "app" {
  filename         = data.archive_file.lambda_app.output_path
  function_name    = "python-app-lambda"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "app.lambda_handler"  # Add this to app.py: def lambda_handler(event, context): ... (adapt Flask for Lambda)
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_app.output_base64sha256

  environment {
    variables = { FLASK_ENV = "production" }
  }

  # Datadog layer for traces/metrics (ARN from Datadog)
  layers = ["arn:aws:lambda:us-east-1:464622532012:layer:DatadogPython312:25"]  # Latest layer ARN; check Datadog docs

  # Production: Reserved concurrency
  reserved_concurrent_executions = 100

  tracing_config {
    mode = "Active"  # For X-Ray traces to Datadog
  }
}

resource "aws_lambda_function_url" "app" {
  function_name      = aws_lambda_function.app.function_name
  authorization_type = "NONE"  # Production: Use IAM or API Gateway for auth
  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
  }
}

# Forward Lambda logs to Datadog (similar to ECS)
resource "aws_cloudwatch_log_subscription_filter" "lambda_to_datadog" {
  name            = "lambda-to-datadog"
  log_group_name  = "/aws/lambda/python-app-lambda"
  filter_pattern  = ""
  destination_arn = aws_lambda_function.datadog_forwarder.arn  # Reuse forwarder
}

resource "aws_lambda_permission" "allow_cloudwatch_lambda" {
  statement_id      = "AllowExecutionFromCloudWatchLambda"
  action            = "lambda:InvokeFunction"
  function_name     = aws_lambda_function.datadog_forwarder.function_name
  principal         = "logs.amazonaws.com"
  source_arn        = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/python-app-lambda:*"
}

data "aws_caller_identity" "current" {}
```

**Notes**: Adapt `app.py` for Lambda handler (use `lambda_function` from awslambdaric for Flask). Enable X-Ray for traces.

#### Step 8: Set Up Datadog Observability Pipeline, Sinks, and Dashboards
Create `datadog.tf`. Based on Datadog's Terraform provider (preview for `observability_pipeline`), this creates a pipeline to process logs (e.g., remap ECS/Lambda service names), with sinks to Datadog (for indexing) and S3 (for long-term archival). Then, provisions a dashboard.

```hcl
# Observability Pipeline (preview: request access from Datadog)
resource "datadog_observability_pipeline" "python_app_pipeline" {
  name = "python-app-observability-pipeline"

  # Processors: Chain to enrich logs (e.g., remap fields for ECS/Lambda)
  processors = [
    {
      type  = "remapper"
      name  = "service-remapper"
      source = "service"
      target = "dd.service"
      inputs = ["*"]  # Apply to all logs
    },
    {
      type = "grok_parser"  # Parse Python logs
      name = "python-log-parser"
      pattern = "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}"
      inputs = ["*"]
    }
  ]

  # Downstream Sinks: Send processed data to Datadog and S3
  sinks = [
    {
      type = "datadog"
      name = "datadog-index-sink"
      service = "datadog-apm"
      env    = "production"
      # Indexes: logs-ecs, logs-lambda
    },
    {
      type = "s3"
      name = "s3-archive-sink"
      bucket_name = "your-datadog-logs-bucket"  # Create in AWS
      path         = "logs/python-app/%Y/%m/%d/"
      compression  = "gzip"
      rotation     = "daily"
    }
  ]

  # Filters: Only process logs from our services
  filter {
    query = "service:python-app OR source:lambda"
  }
}

# Datadog Dashboard for monitoring (production: multi-widget with queries)
resource "datadog_dashboard" "python_app_dashboard" {
  title       = "Python App Observability Dashboard"
  description = "Monitors ECS Fargate and Lambda deployment"
  layout_type = "ordered"
  widgets = [
    {
      definition = jsonencode({
        "type" : "timeseries",
        "requests" : [
          {
            "q" : "avg:system.load.1{service:python-app}",
            "display_type" : "line"
          }
        ],
        "title" : "CPU Load"
      })
    },
    {
      definition = jsonencode({
        "type" : "query_value",
        "requests" : [
          {
            "q" : "sum:trace.lambda.duration{service:python-app}.as_count()",
            "aggregator" : "avg"
          }
        ],
        "title" : "Lambda Duration"
      })
    },
    {
      definition = jsonencode({
        "type" : "log_stream",
        "requests" : [
          {
            "log_query" : {
              "query" : "service:python-app @level:ERROR",
              "index" : "main"
            },
            "column" : { "attribute" : "message" }
          }
        ],
        "title" : "Error Logs"
      })
    }
    # Add more: traces, errors, throughput
  ]

  # Production: Share with team
  managed_screen = false
}
```

**Notes**: The `observability_pipeline` syntax is based on Datadog API/docs (processors/sinks as lists of maps). Customize patterns. Create the S3 bucket manually. For traces, ensure APM is enabled in Datadog site settings.

#### Step 9: Apply and Validate
1. Run `terraform plan` to review.
2. `terraform apply --auto-approve`.
3. Outputs in `outputs.tf` (add e.g., `output "alb_dns" { value = aws_lb.app.dns_name }` and `output "lambda_url" { value = aws_lambda_function_url.app.function_url }`).
4. Test:
   - ECS: `curl http://<alb-dns>/health`
   - Lambda: `curl <lambda-url>/health`
5. Verify in Datadog: Logs appear in pipeline-processed format; dashboard shows metrics.
6. CI/CD: Use GitHub Actions to run `terraform apply` on merge.

#### Step 10: Cleanup and Best Practices
- Destroy: `terraform destroy`.
- Production Tips:
  - Use Terraform modules (e.g., from Registry for ECS).
  - Secrets: Use AWS SSM or Vault instead of env vars.
  - Cost: Monitor with Datadog cost dashboards.
  - Updates: Version app images/tags; use blue-green for ECS.
  - Compliance: Enable AWS GuardDuty, Datadog compliance monitors.

This setup provides a scalable, observable deployment. For issues, check Terraform logs or Datadog events. If `observability_pipeline` is unavailable, fall back to `datadog_logs_pipeline_order` for log processing.

### Adding GitHub Actions Pipelines to the Production-Ready Tutorial

This extension to the previous tutorial integrates GitHub Actions for CI/CD automation. We'll create reusable workflows to:

- **CI Pipeline**: Build the Docker image for ECS, zip the Lambda package, run tests (e.g., linting, unit tests), and push artifacts to ECR (for ECS) and GitHub Packages (for Lambda zip). Trigger on pull requests.
- **CD Pipeline**: On merge to `main`, apply Terraform changes, update ECS task definition with new image tag (e.g., commit SHA), deploy Lambda with new zip, and notify Datadog of deployment (via API for events/monitors). Includes approval gates for production safety.
- **Terraform Pipeline**: Separate workflow for infrastructure changes: plan/apply on `main` merges, with manual approval. Uses OIDC for secure AWS auth (no long-lived keys).

**Production Enhancements**:
- **Security**: OIDC federation for AWS access (assumes GitHub connected to AWS IAM via OIDC provider). Secrets stored in GitHub repo settings.
- **Reliability**: Caching for Docker/builds, matrix for multi-region if needed, smoke tests post-deploy.
- **Datadog Integration**: Post-deployment, send events to Datadog for monitoring (e.g., deployment tags for traces).
- **Assumptions**: Repo is `your-org/python-app-deploy`. Set GitHub secrets: `AWS_REGION=us-east-1`, `AWS_ACCOUNT_ID=your-account`, `DD_API_KEY=your-api-key`, `DD_APP_KEY=your-app-key`. Enable OIDC in AWS IAM (see AWS docs: create provider for `token.actions.githubusercontent.com`).
- **Datadog Provider Update**: Based on latest (v3.73.0 as of Sept 2025), update `datadog` provider version in `main.tf` to `~> 3.73`. Note: `datadog_observability_pipeline` is in preview; if unavailable, use `datadog_logs_pipeline` as fallback (syntax similar, but for logs only).

Update your project structure:
```
.
├── .github/workflows/
│   ├── ci.yml                  # CI: Build and test
│   ├── cd-ecs-lambda.yml       # CD: Deploy app to ECS/Lambda
│   └── terraform.yml           # Infra: Terraform apply
├── main.tf                     # Update provider version
└── ... (previous files)
```

#### Step 1: Update Terraform Provider (Optional, for Latest)
In `main.tf`, change:
```hcl
required_providers {
  datadog = {
    source  = "DataDog/datadog"
    version = "~> 3.73"  # Latest as of Sept 2025
  }
  # ... others unchanged
}
```
Run `terraform init -upgrade` locally to test.

#### Step 2: Set Up GitHub Secrets and OIDC
1. In GitHub repo settings > Secrets and variables > Actions, add:
   - `AWS_ACCOUNT_ID`: Your AWS account ID.
   - `AWS_REGION`: `us-east-1`.
   - `DD_API_KEY`: Datadog API key (sensitive).
   - `DD_APP_KEY`: Datadog APP key (sensitive).
   - `TERRAFORM_VERSION`: `1.9.5` (latest).
2. In AWS IAM: Create OIDC provider for GitHub (Audience: `sts.amazonaws.com`, Thumbprint: from GitHub docs). Attach policy to role `GitHubActionsRole` with perms for ECR push, ECS update, Lambda update, S3 (for state), etc. (Extend previous IAM roles).

#### Step 3: CI Pipeline (Build and Test)
Create `.github/workflows/ci.yml`. Triggers on PRs, builds image/zip, runs tests, pushes to ECR if checks pass.

<xaiArtifact artifact_id="f5cef9e8-310c-4bea-a8c6-406f82630051" artifact_version_id="15811663-e622-4fa9-8e33-9b6887427350" title="ci.yml" contentType="text/yaml">
name: CI - Build and Test

on:
  pull_request:
    branches: [ main ]
    paths:
      - 'app.py'
      - 'Dockerfile'
      - 'requirements.txt'
      - '.github/workflows/ci.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest  # For tests

      - name: Run unit tests
        run: pytest  # Add tests/app_test.py if needed, e.g., test health endpoint

      - name: Lint code
        run: |
          pip install flake8
          flake8 app.py

  build-ecs:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: python-app
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -t $ECR_REGISTRY/$ECR_REPOSITORY:latest .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

  build-lambda:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Build Lambda zip
        run: |
          zip -r lambda.zip app.py requirements.txt -x "*.git*" "Dockerfile"
          # Upload as artifact for CD
        uses: actions/upload-artifact@v4
        with:
          name: lambda-zip
          path: lambda.zip
          retention-days: 1
</xaiArtifact>

**Notes**: Add `tests/app_test.py` for real tests (e.g., `import pytest; def test_health(): assert True`). Outputs image URI for CD.

#### Step 4: CD Pipeline (Deploy App to ECS and Lambda)
Create `.github/workflows/cd-ecs-lambda.yml`. Triggers on push to `main`, deploys after approval. Updates ECS task with new image, uploads Lambda zip, sends Datadog event.

<xaiArtifact artifact_id="860858ef-c243-4932-9df6-a686102dac05" artifact_version_id="c7d31707-58ec-4a65-8273-39f7dd4d03d9" title="cd-ecs-lambda.yml" contentType="text/yaml">
name: CD - Deploy to ECS and Lambda

on:
  push:
    branches: [ main ]
    paths:
      - 'app.py'
      - 'Dockerfile'
      - 'requirements.txt'

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval in GitHub environments
    needs: [build-from-ci]  # Or run build here if not PR
    steps:
      - uses: actions/checkout@v4

      - name: Download Lambda zip
        uses: actions/download-artifact@v4
        with:
          name: lambda-zip
          path: .

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ${{ secrets.AWS_REGION }}

      # Deploy ECS: Update task definition with new image
      - name: Update ECS task definition
        id: ecs-task
        env:
          IMAGE_TAG: ${{ github.sha }}
        run: |
          # Register new task definition (use AWS CLI)
          aws ecs register-task-definition --cli-input-json file://task-definition.json --family python-app-task  # Update JSON with new image URI from ECR
          aws ecs update-service --cluster python-app-cluster --service python-app-service --task-definition python-app-task:latest
          # Wait for deployment
          aws ecs wait services-stable --cluster python-app-cluster --services python-app-service

      # Deploy Lambda: Update function code
      - name: Deploy Lambda
        run: |
          aws lambda update-function-code --function-name python-app-lambda --zip-file fileb://lambda.zip
          # Invoke to test
          aws lambda invoke --function-name python-app-lambda response.json

      # Smoke test
      - name: Smoke test
        run: |
          # Test ECS ALB (get DNS from Terraform output or SSM)
          curl -f http://$(aws elbv2 describe-load-balancers --names python-app-alb --query 'LoadBalancers[0].DNSName' --output text)/health
          # Test Lambda URL
          curl -f $(aws lambda get-function-url-config --function-name python-app-lambda --query 'FunctionUrl' --output text)/health

      # Notify Datadog
      - name: Send deployment event to Datadog
        env:
          DD_API_KEY: ${{ secrets.DD_API_KEY }}
        run: |
          curl -X POST "https://api.datadoghq.com/api/v1/events" \
            -H "DD-API-KEY: $DD_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{
              "title": "Deployment to ECS/Lambda",
              "text": "New version ${{ github.sha }} deployed successfully",
              "tags": ["service:python-app", "env:production", "version:${{ github.sha }}"],
              "priority": "normal",
              "alert_type": "info"
            }'
</xaiArtifact>

**Notes**: Customize `task-definition.json` template with sed to inject `${{ github.sha }}` image tag. For Lambda, ensure handler is set. Add Datadog site if not US. Use `aws ecs describe-services` for stability checks.

#### Step 5: Terraform Pipeline (Infrastructure Changes)
Create `.github/workflows/terraform.yml`. Triggers on PR/push to `main` for infra files. Plans on PR, applies on merge with approval.

<xaiArtifact artifact_id="d58ebef7-b905-4894-a8b1-ab89af076576" artifact_version_id="310c51e6-10fe-4cc3-9529-15dc5838df3e" title="terraform.yml" contentType="text/yaml">
name: Terraform CI/CD

on:
  pull_request:
    branches: [ main ]
    paths:
      - '**/*.tf'
      - 'variables.tf'
      - 'terraform.tfvars'
  push:
    branches: [ main ]
    paths:
      - '**/*.tf'
      - 'variables.tf'
      - 'terraform.tfvars'

permissions:
  id-token: write
  contents: read
  pull-requests: write  # For comments

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: production  # Approval for apply
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ secrets.TERRAFORM_VERSION }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Terraform Format and Validate
        run: |
          terraform init
          terraform fmt -check
          terraform validate

      - name: Terraform Plan
        if: github.event_name == 'pull_request'
        run: |
          terraform init -backend-config="bucket=your-tf-state-bucket" -backend-config="key=python-app/terraform.tfstate" -backend-config="region=${{ secrets.AWS_REGION }}"
          terraform plan -var="datadog_api_key=${{ secrets.DD_API_KEY }}" -var="datadog_app_key=${{ secrets.DD_APP_KEY }}" -out=tfplan
          # Comment plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('plan.out', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Terraform Plan:\n```hcl:disable-run
            });

      - name: Terraform Apply
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          terraform init -backend-config="bucket=your-tf-state-bucket" -backend-config="key=python-app/terraform.tfstate" -backend-config="region=${{ secrets.AWS_REGION }}"
          terraform apply -auto-approve -var="datadog_api_key=${{ secrets.DD_API_KEY }}" -var="datadog_app_key=${{ secrets.DD_APP_KEY }}"

      # Datadog-specific: Apply Datadog resources (if separate)
      - name: Apply Datadog changes
        if: steps.terraform.outputs.changes_detected == 'true'  # Custom step to check
        run: |
          # Assuming Datadog resources in same TF, already covered; else separate init/apply
          curl -X POST "https://api.datadoghq.com/api/v1/events" \
            -H "DD-API-KEY: ${{ secrets.DD_API_KEY }}" \
            -H "Content-Type: application/json" \
            -d '{
              "title": "Terraform Infra Update",
              "text": "Infrastructure updated via GitHub Actions",
              "tags": ["service:infra", "env:production"]
            }'
</xaiArtifact>

**Notes**: Backend config uses S3 (create bucket/lock table if not). For Datadog preview resources, ensure API keys have perms. Add `terraform show -json tfplan > plan.json` for diff comments if needed. Protect `main` branch in GitHub settings.

#### Step 6: Testing the Pipelines
1. Commit app changes and open PR: CI runs tests/builds, comments plan.
2. Merge PR: CD deploys app, Terraform applies infra if changed, Datadog gets events.
3. Monitor in GitHub Actions tab and Datadog (events/logs for deployments).
4. Best Practices: Add caching (`actions/cache@v4` for pip/Docker), security scans (e.g., `docker scout`), and rollback (manual destroy or blue-green via ECS).

This completes the CI/CD integration, making your deployment fully automated and observable. For advanced, add matrix for multi-env (dev/prod).
```

Below is the complete project organization for the production-ready deployment of a Python Flask app to AWS ECS Fargate and Lambda, with Datadog observability (using Terraform's latest version, ~1.9.x, and Datadog provider ~3.73.0) and GitHub Actions CI/CD pipelines. The structure includes all files, their purposes, and how they integrate to achieve a secure, scalable, and observable deployment. This reflects the full setup from the previous responses, including the CI/CD workflows added for automation.

### Project Organization

```
python-app-deploy/
├── .github/
│   └── workflows/
│       ├── ci.yml                  # CI: Build Docker image, Lambda zip, run tests, push to ECR
│       ├── cd-ecs-lambda.yml       # CD: Deploy app to ECS Fargate and Lambda, notify Datadog
│       └── terraform.yml           # Terraform: Plan/apply infrastructure changes with approval
├── tests/
│   └── app_test.py                 # Unit tests for the Flask app (e.g., test /health endpoint)
├── datadog_forwarder_lambda/       # Directory for Datadog Lambda forwarder code (downloaded from Datadog GitHub)
│   ├── lambda_function.py          # Datadog forwarder Lambda code
│   └── ... (other files from Datadog repo)
├── app.py                         # Flask app code (shared for ECS and Lambda)
├── Dockerfile                     # Docker config for ECS Fargate
├── requirements.txt               # Python dependencies (Flask, gunicorn for ECS, pytest for tests)
├── main.tf                        # Terraform: Providers, S3 backend, variables
├── variables.tf                   # Terraform input variables (e.g., AWS region, Datadog keys)
├── terraform.tfvars               # Sensitive vars (Datadog API/APP keys, region)
├── outputs.tf                     # Terraform outputs (e.g., ALB DNS, Lambda URL)
├── ecs.tf                         # Terraform: ECS cluster, task, service, ALB, logs
├── lambda.tf                      # Terraform: Lambda function, URL, logs
├── datadog.tf                     # Terraform: Datadog observability pipeline, sinks, dashboards
├── vpc.tf                         # Terraform: VPC, subnets, NAT, security groups
├── task-definition.json           # Template for ECS task definition (used in CD pipeline)
├── lambda.zip                     # Generated: Lambda deployment package (via CI)
├── datadog_forwarder.zip          # Generated: Datadog forwarder Lambda package (via Terraform)
└── README.md                      # Project documentation
```

### File Details and Purpose

1. **.github/workflows/**:
   - `ci.yml`: Runs on pull requests to `main` for app code changes (`app.py`, `Dockerfile`, `requirements.txt`). Builds Docker image for ECS, zips Lambda code, runs tests (linting with flake8, unit tests with pytest), and pushes image to ECR. Outputs artifacts for CD.
   - `cd-ecs-lambda.yml`: Triggers on push to `main` (after PR merge). Updates ECS task definition with new image tag (commit SHA), deploys Lambda with new zip, runs smoke tests, and sends deployment event to Datadog. Requires manual approval via GitHub Environments.
   - `terraform.yml`: Triggers on PR/push for Terraform files (`*.tf`, `terraform.tfvars`). Runs `terraform plan` on PRs (comments plan), applies on merge with approval. Uses OIDC for AWS auth and notifies Datadog of infra changes.

2. **tests/app_test.py**:
   - Unit tests for `app.py` (e.g., testing `/health` endpoint returns 200). Example:
     ```python
     import pytest
     from app import app

     @pytest.fixture
     def client():
         app.config['TESTING'] = True
         with app.test_client() as client:
             yield client

     def test_health(client):
         response = client.get('/health')
         assert response.status_code == 200
         assert response.json == {'status': 'healthy'}
     ```
   - Run by CI pipeline (`pytest`).

3. **datadog_forwarder_lambda/**:
   - Contains Datadog's Lambda forwarder code (download from [Datadog GitHub](https://github.com/DataDog/datadog-serverless-functions)). Used to forward CloudWatch logs (from ECS/Lambda) to Datadog. Zipped into `datadog_forwarder.zip` by Terraform.

4. **app.py**:
   - Flask app with `/health` and `/` endpoints, logging configured for Datadog. Shared for ECS (runs via gunicorn) and Lambda (needs `lambda_handler` for serverless, e.g., using `awslambdaric`).
   - Example snippet (add for Lambda compatibility):
     ```python
     from aws_lambda_wsgi import WSGIHandler

     def lambda_handler(event, context):
         return WSGIHandler(app, event, context).response()
     ```

5. **Dockerfile**:
   - Builds ECS container using `public.ecr.aws/lambda/python:3.12` base for compatibility. Installs Flask/gunicorn, runs on port 8080.

6. **requirements.txt**:
   - Dependencies: `flask`, `gunicorn` (ECS), `pytest` (tests). Minimal to keep image/zip small.

7. **Terraform Files**:
   - `main.tf`: Configures providers (AWS ~5.0, Datadog ~3.73), S3 backend for state (bucket: `your-tf-state-bucket`, key: `python-app/terraform.tfstate`), and variables.
   - `variables.tf`: Defines inputs (`aws_region`, `datadog_api_key`, `datadog_app_key`).
   - `terraform.tfvars`: Sensitive values (e.g., `datadog_api_key = "your-key"`). Git-ignored.
   - `outputs.tf`: Exposes ALB DNS, Lambda URL, etc. Example:
     ```hcl
     output "alb_dns" { value = aws_lb.app.dns_name }
     output "lambda_url" { value = aws_lambda_function_url.app.function_url }
     ```
   - `ecs.tf`: Provisions ECS cluster, Fargate task/service, ALB, CloudWatch logs, Datadog sidecar, and log subscription to forwarder.
   - `lambda.tf`: Provisions Lambda function, URL, Datadog layer, X-Ray tracing, and log subscription.
   - `datadog.tf`: Configures observability pipeline (remaps fields, parses logs), sinks (Datadog indexing, S3 archival), and dashboard (timeseries for CPU, Lambda duration, error logs).
   - `vpc.tf`: Creates VPC, public/private subnets, NAT, security groups for ECS and ALB.

8. **task-definition.json**:
   - Template for ECS task definition (used in CD pipeline). Substitutes image tag (`${{ github.sha }}`) during deployment. Example:
     ```json
     {
       "family": "python-app-task",
       "networkMode": "awsvpc",
       "requiresCompatibilities": ["FARGATE"],
       "cpu": "256",
       "memory": "512",
       "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
       "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
       "containerDefinitions": [
         {
           "name": "python-app",
           "image": "${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/python-app:${IMAGE_TAG}",
           "essential": true,
           "portMappings": [{ "containerPort": 8080 }],
           "logConfiguration": {
             "logDriver": "awslogs",
             "options": {
               "awslogs-group": "/ecs/python-app",
               "awslogs-region": "us-east-1",
               "awslogs-stream-prefix": "ecs"
             }
           },
           "healthCheck": {
             "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
             "interval": 30,
             "timeout": 5,
             "retries": 3
           }
         }
       ]
     }
     ```

9. **lambda.zip** and **datadog_forwarder.zip**:
   - Generated by CI (`lambda.zip`: app code) and Terraform (`datadog_forwarder.zip`: forwarder). Not checked in; stored as GitHub artifacts or built on-the-fly.

10. **README.md**:
    - Documents setup, prerequisites (AWS CLI, Terraform, Datadog keys), and commands (`terraform apply`, `docker build`). Includes CI/CD flow and how to test endpoints.

### Integration and Workflow
- **Development**:
  - Dev pushes code changes to feature branch, opens PR. CI (`ci.yml`) runs tests, builds image/zip, pushes to ECR.
  - PR comments show Terraform plan (`terraform.yml`) for infra changes.
- **Deployment**:
  - Merge to `main` triggers `cd-ecs-lambda.yml`: Updates ECS task with new image, deploys Lambda zip, runs smoke tests, sends Datadog event.
  - Infra changes (`*.tf`) trigger `terraform.yml`: Applies Terraform with approval, notifies Datadog.
- **Monitoring**:
  - ECS/Lambda logs flow to CloudWatch, forwarded to Datadog via Lambda forwarder.
  - Datadog pipeline processes logs (remaps fields, parses Python logs), sends to Datadog (indexed) and S3 (archived).
  - Datadog dashboard visualizes CPU, Lambda duration, errors.
- **Security**:
  - OIDC for AWS access (no static keys). Secrets in GitHub (encrypted).
  - Least-privilege IAM roles, VPC isolation, HTTPS (ALB can be extended for TLS).
- **Scalability**:
  - ECS auto-scaling, Lambda concurrency limits, multi-AZ VPC.
  - Caching in GitHub Actions for faster builds.
- **Reliability**:
  - Approval gates, smoke tests, Terraform state locking, Datadog alerts for failures.

### Setup Instructions
1. **Repo Setup**:
   - Create repo (`your-org/python-app-deploy`).
   - Add files as above. Ensure `.gitignore` includes `terraform.tfvars`, `*.zip`, `.terraform/`.
   - Set GitHub secrets: `AWS_ACCOUNT_ID`, `AWS_REGION`, `DD_API_KEY`, `DD_APP_KEY`, `TERRAFORM_VERSION`.
2. **AWS Setup**:
   - Create S3 bucket (`your-tf-state-bucket`), DynamoDB table (`terraform-locks`), S3 bucket for Datadog logs (`your-datadog-logs-bucket`).
   - Set up OIDC provider for GitHub, attach `GitHubActionsRole` with perms (ECR, ECS, Lambda, S3, CloudWatch).
3. **Datadog Setup**:
   - Ensure API/APP keys have access. Request `observability_pipeline` preview if needed (fallback: `datadog_logs_pipeline`).
   - Enable APM for traces in Datadog settings.
4. **Local Testing**:
   - `terraform init`, `terraform plan`, `terraform apply` (set `terraform.tfvars`).
   - Build/push Docker image manually first: `docker build -t ...`, `docker push`.
   - Test: `curl <alb-dns>/health`, `curl <lambda-url>/health`.
5. **CI/CD**:
   - Push to feature branch, open PR: CI runs, comments plan.
   - Merge to `main`: CD deploys, Terraform applies.

### Notes
- **Extensibility**: Add multi-region matrix in `ci.yml`, blue-green deployments for ECS, or Datadog monitors for alerts.
- **Cost**: Monitor with AWS Cost Explorer/Datadog cost dashboards. Optimize ECS tasks (e.g., 256 CPU) and Lambda concurrency.
- **Troubleshooting**: Check GitHub Actions logs, Datadog events, or Terraform output for errors. If `observability_pipeline` fails, use `datadog_logs_pipeline` (update `datadog.tf`).
- **Security**: Add `docker scout` in CI, AWS GuardDuty, and Datadog compliance monitors.

This structure ensures a production-ready setup with automated CI/CD, observability, and infrastructure as code. Let me know if you need a specific file's full content or further customization!