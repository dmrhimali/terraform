## Run AWS Batch  job
AWS:
  >AWS Batch is a fully managed batch computing service that plans, schedules, and runs your containerized batch ML, simulation, and analytics workloads across the full range of AWS compute offerings, such as Amazon ECS, Amazon EKS, AWS Fargate, and Spot or On-Demand Instances.

In this tutorial we setup a aws batch environment and a batch job to run user buit ecr image

References:

- part1: https://www.youtube.com/watch?v=-gX9Sr6fdVc 
- part2: https://www.youtube.com/watch?v=HTtOJn2RHqA

## Create dynamodb table Testtable:

> aws console 

> dynamodb

> create table

> tablename: TestTable

> Primary key: pk (type:Number)

> add sort key: sk (type: Number)

## Create ecr repository

> aws console

> ecr

> create repository

> name: dmrh/aws-batch-demo 

> create repository


## Create docker image of python script

This python script push some random data to test table created above

To create image: dmrh/aws-batch-demo:latest:

> $ cd home/bitbucket/terraform/batch/python-load-dynamodb 

> $ export AWS_ACCOUNT_ID=xxxx

> $ export REPOSITORY_URL=$AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dmrh/aws-batch-demo

> $ export IMAGE_TAG=latest

> $ docker build -t $REPOSITORY_URL:$IMAGE_TAG .

output: `Successfully tagged 545200963109.dkr.ecr.us-east-1.amazonaws.com/dmrh/aws-batch-demo:latest`

## Push docker image to ecr:

Login to ecr:

> $aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 545200963109.dkr.ecr.us-east-1.amazonaws.com

output:
`Login Succeeded`


> $ docker push $REPOSITORY_URL:$IMAGE_TAG

now ecr should show image wit uri (545200963109.dkr.ecr.us-east-1.amazonaws.com/dmrh/aws-batch-demo:latest) in dmrh/aws-batch-demo repo.


## Create batch environment

The vcpus ans memory defined in compute env will be limited by instance type:

see https://aws.amazon.com/ec2/instance-types/

>aws console

>batch

>skip wizard

>create compute environment

>Compute environment type: managed

>Service role: create new role

>Instance role: create new role

>EC2 Keypair: dmrhimali_keypair

>name: aws-batch-demo-env

>provisioning model: on-demand

>Allowed instance types: optimal 

(Optimal chooses the best fit of M4, C4, and R4 instance types available in the region.
Jobs define their vCPU and memory requirements at submission and that information is used to match the job with the most appropriately sized instance.)

>Allocation strategy: BEST_FIT

Allocation Strategies allow you to choose how Batch launches instances on your behalf. We recommend Best Fit Progressive for On-Demand CEs and Spot Capacity Optimized for Spot CEs. This will make it much more likely Batch will be able to secure the needed capacity for your workloads by pulling from diverse instance types. However, if you want to ensure Batch chooses only the lowest priced instance types appropriate to your jobs, you can select the Best Fit strategy.

> Minimum VCPUs : 0

By keeping this set to 0 you will not have instance time wasted when there is no work to be run. If you set this above zero you will maintain that number of vCPUs at all times.

> Desired VCPUs: 1

> Maximum VCPUs: 4

EC2 instance type limits will determine the maximum vCPUs you can have. see https://aws.amazon.com/ec2/instance-types/

> VPC Id: default

> Subnets: select all

> Security Group: default

> EC2 Tags (key: Name, value:aws-batch-demo ) for identifying ec2 instance

## Create batch job queue

> aws console

> batch

> job queus

> create queue

> queue name: aws-batch-demo-queue

> priority: 100

> select a compute environment: aws-batch-demo-env

> create

## Create iam role that allow put items to dynamodb


> aws console

> iam

> roles

> create role

> Choose a use case: Elastic Container Service

> Select your use case: Elastic Container Service Task

> Next:Permissions

> select AmazonDynamoDBFullAccess

> Next:Tags

> Next: Review

> Role name: AWSBatchEcs

> Create

## Create a batch job definition


> aws console

> batch

> job definitions

> create

> Job definition name: aws-batch-job-def

> Job role: AWSBatchEcs

> Container image: 545200963109.dkr.ecr.us-east-1.amazonaws.com/dmrh/aws-batch-demo:latest (uri of ecr image)

> vCPUs: 2

> Memory (MiB): 400

> Create job definition

## Create Batch Job

> aws console

> batch

> jobs

> submit job

> Job name: aws-batch-demo-job

> Job definition: select aws-batch-job-def:1

>Job queue: aws-batch-demo-queue

>Job Type: single

> vCPUs: 2 (filled by job def)

> Memory (MiB): 400 (filled by job def)

> submit job

After few minutes it moves to SUCCEEDED State in Batch Dashboard

After looking at Batch Compute Env summary, the AMI used: ami-0e2ff28bfb72a4e45

Recent issue with job:

https://stackoverflow.com/questions/46265278/aws-batch-client-error-invalid-iaminstanceprofile

deleting and recreating quwuw issuw:x   
https://github.com/terraform-providers/terraform-provider-aws/issues/2696


## Notes:
- make sure The desired vcpus specified for compute env in job definition >= created job vcpus (https://www.youtube.com/watch?v=6x_SgFEqoQI troubleshooting)

- For the security group associated with compute env should have an outbound rule to allow all traffic:
  - `All traffic	All	All	0.0.0.0/0`

```terraform
  resource "aws_security_group" "insight-service-batch-compute-environment-sg" {
  name        = "${lower(var.environment_tag)}-insight-service-batch-compute-environment-sg"
  description = "Security group for insight service  batch compute environment"
  vpc_id      = "${var.vpc_id}"

  //ingress {
  //  from_port   = 22
  //  to_port     = 22
  //  protocol    = "tcp"
  //  cidr_blocks = ["${module.cidrs-offices.all}"]
  //  self        = true
  //}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${lower(var.environment_tag)}-insight-service-batch-compute-environment-sg"
    environment = "${lower(var.environment_tag)}"
    team        = "aoshima"
  }
}
```

- No requirement for inbound cpu except if you want ssh (AWS Batch container instances do not require any inbound ports to be open.): https://docs.aws.amazon.com/batch/latest/userguide/get-set-up-for-aws-batch.html


- The ecs instance role used for compute env should use a profile than iam role: 
  - e.g. `Instance role arn:aws:iam::545200963109:instance-profile/personal-ecs_instance_role`

- for subnets assocuiated with compute env, for each , if auto-assign-public-ip is on, the routing table shoud have igw(internet gateway record), or if it is off should have nat gateway record.

- scheduling: https://aws.amazon.com/blogs/database/scheduling-and-running-amazon-rds-jobs-with-aws-batch-and-amazon-cloudwatch-rules/
tf:
- https://github.com/terraform-providers/terraform-provider-aws/issues/5524

https://aws.amazon.com/premiumsupport/knowledge-center/batch-target-cloudwatch-events-rules/

https://medium.com/@ayush.choubey/scheduled-serverless-cron-job-3cf10091ddf6

## Cron jobs in cloudwatch

### Syntax

`cron(fields)`

Field	        Values	           Wildcards
Minutes       0-59                , - * /
Hours         0-23                , - * /
Day-of-month  1-31                , - * ? / L W
Month         1-12 or JAN-DEC     , - * /
Day-of-week   1-7 or SUN-SAT      , - * ? L #
Year          1970-2199           , - * /

### Wildcards

The `, (comma)` wildcard includes additional values. In the Month field, JAN,FEB,MAR would include January, February, and March.

The `- (dash)` wildcard specifies ranges. In the Day field, 1-15 would include days 1 through 15 of the specified month.

The `* (asterisk)` wildcard includes all values in the field. In the Hours field, * would include every hour. You cannot use * in both the Day-of-month and Day-of-week fields. If you use it in one, you must use ? in the other.

The` / (forward slash)` wildcard specifies increments. In the Minutes field, you could enter 1/10 to specify every tenth minute, starting from the first minute of the hour (for example, the 11th, 21st, and 31st minute, and so on).

The `? (question mark)` wildcard specifies one or another. In the Day-of-month field you could enter 7 and if you didn't care what day of the week the 7th was, you could enter ? in the Day-of-week field.

The `L wildcard` in the Day-of-month or Day-of-week fields specifies the last day of the month or week.

The` W wildcard` in the Day-of-month field specifies a weekday. In the Day-of-month field, 3W specifies the weekday closest to the third day of the month.

The # wildcard in the Day-of-week field specifies a certain instance of the specified day of the week within a month. For example, 3#2 would be the second Tuesday of the month: the 3 refers to Tuesday because it is the third day of each week, and the 2 refers to the second day of that type within the month.
https://docs.aws.amazon.com/lambda/latest/dg/services-cloudwatchevents-expressions.html
https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html#CronExpressions

### Examples

`cron(Minutes Hours Day-of-month Month Day-of-week Year)`

`"cron(0 11 * * ? *)"`
 
 The asterisks are wildcards that include all values and the question mark means “nothing specified” or “I don’t care”. 
 
 In this case, the parameter asks “what day of the week?” and the question mark responds with an inclusive wildcards which neither specifics Mon-Sun or 1-7.

Of course cron jobs can do rates as well. 

If you wanted something to run every 5 minutes during weekdays you’d simply create a job that goes: 
`cron 0/5 * ? * MON-FRI *` 

But a rate expression would be much simpler with just: `rate(5 minutes)`.

Every sunday at 10am: `cron(0 10 ? * SUN *)`


| Frequency	|                                                  Expression |
| ----------|--------------------------------------------------------------|
| 10:15 AM (UTC) every day|                                     cron(15 10 * * ? *)| 
| 6:00 PM Monday through Friday    |                            cron(0 18 ? * MON-FRI *)| 
| 8:00 AM on the first day of the month  |                      cron(0 8 1 * ? *)| 
| Every 10 min on weekdays         |                            cron(0/10 * ? * MON-FRI *)| 
| Every 5 minutes between 8:00 AM and 5:55 PM weekdays  |       cron(0/5 8-17 ? * MON-FRI *)| 
| 9:00 AM on the first Monday of each month     |               cron(0 9 ? * 2#1 *)| 
