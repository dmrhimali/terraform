## check existing resources in an account
aws cli command:
`aws resourcegroupstaggingapi get-resources --region us-east-1 | jq '.ResourceTagMappingList[].ResourceARN'`

so you can check and delete.

## Manage versions of terraform

### Install  tfenv

`brew install tfenv`


### view terraform versions
After installation via `brew install tfenv`, this allows you to easily discover, install and activate any Terraform version:
$ `tfenv list-remote`
0.12.0
0.12.0-rc1
0.12.0-beta2
0.12.0-beta1
0.12.0
0.11.14
...

### install terraform version you need

`tfenv install 0.11.14`

```sh
$ tfenv install 0.11.14
[INFO] Installing Terraform v0.11.14
[INFO] Downloading release tarball from https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_darwin_amd64.zip
...
[INFO] Installation of terraform v0.11.14 successful
[INFO] Switching to v0.11.14
[INFO] Switching completed
If you want to switch to a different version:
$ tfenv use 0.12.0
[INFO] Switching to v0.12.0
[INFO] Switching completed
```

### reference a lamba source zip file in s3 bucket

if your lambda zip is uploaded to a s3 bucket by a different project, you can create lambda as follows:
`s3_object_version` lets terraform apply identify that lambda zip has changed , if it has changed since last terraform apply.

```bash
data "aws_s3_bucket_object" "create-schema" {
  bucket = "${aws_s3_bucket.personalize-lambda.bucket}"
  key    = "createschema.zip"
}

resource "aws_lambda_function" "create-schema" {
  s3_bucket         = "${data.aws_s3_bucket_object.create-schema.bucket}"
  s3_key            = "${data.aws_s3_bucket_object.create-schema.key}"
  s3_object_version = "${data.aws_s3_bucket_object.create-schema.version_id}"
  function_name = "${lower(var.environment_tag)}-create-schema"
  description   = "Creates a schema in personalize"
  handler       = "createschema.lambda_handler"
  runtime       = "python3.7"

  kms_key_arn = "${data.aws_kms_key.env-kms.arn}"
  role        = "${aws_iam_role.lambda-role.arn}"
  timeout     = 30
  memory_size = 1216
  layers      = ["${aws_lambda_layer_version.lambda_layer.arn}"]

  vpc_config {
    subnet_ids         = ["${data.aws_subnet_ids.lambda-subnet-ids.ids}"]
    security_group_ids = ["${data.aws_security_group.erewhon_lambda_sg.id}"]
  }

  environment {
    variables = {
      ENV = "${upper(var.environment_tag)}"
    }
  }

  tags = {
    Name        = "${lower(var.environment_tag)}-create-schema"
    environment = "${lower(var.environment_tag)}"
    team        = "aoshima"
  }
}
```

The other project to push zip file (this project only host lambda code and piepline to zip them up and push to s3 bucket):

```bash
(base)  rdissanayakam@RBH12855  ~/vp/gitlab/mithrandir   features/pipeline  tree    
.
├── README.md
├── .gitlab-ci.yml
├── ci
│   └── variables
│       └── playground
└── src
    └── personalize
        ├── dependencies
        │   └── python
        │       ├── __init__.py
        │       └── actions.py
        ├── lambdas
        │   ├── createcampaign
        │   │   ├── __init__.py
        │   │   ├── campaign.py
        │   │   └── requirements.txt
        │   ├── createdataset
        │   │   ├── __init__.py
        │   │   ├── dataset.py
        │   │   └── requirements.txt
        │   ├── createdatasetgroup
        │   │   ├── __init__.py
        │   │   ├── datasetgroup.py
        │   │   └── requirements.txt
        │   ├── createdatasetimportjob
        │   │   ├── __init__.py
        │   │   ├── datasetimport.py
        │   │   └── requirements.txt
        │   ├── createschema
        │   │   ├── __init__.py
        │   │   ├── createschema.py
        │   │   └── requirements.txt
        │   ├── createsolution
        │   │   ├── __init__.py
        │   │   ├── requirements.txt
        │   │   └── solution.py
        │   ├── createsolutionversion
        │   │   ├── __init__.py
        │   │   ├── requirements.txt
        │   │   └── solutionversion.py
        │   ├── notify
        │   │   ├── __init__.py
        │   │   ├── notify.py
        │   │   └── requirements.txt
        │   ├── triggerstatemachine
        │   │   ├── __init__.py
        │   │   ├── requirements.txt
        │   │   └── triggerstatemachine.py
        │   └── updatecampaign
        │       ├── __init__.py
        │       ├── campaign.py
        │       └── requirements.txt
        └── zip

```

`.gitlab-ci.yml`

```yml
stages:
  - build
  - deploy

variables:
  BUCKET_NAME_SUFFIX: "personalize-lambda"

build_zip:
  stage: build
  script:
    - apt-get update
    - apt-get install zip unzip
    - cd src/personalize/lambdas
#    - for i in */; do zip -r "../zip/${i%/}.zip" "$i"; done
    - for dir in */; do ( cd "$dir" && zip  ../../zip/"${dir%/}".zip * ) done
    - cd ../dependencies
    - zip -r ../zip/lambda_layer_payload.zip python
  artifacts:
    expire_in: 1h
    paths:
      - src/personalize/zip
  tags:
    - docker
    - ops

.upload_zip:
  image: python:latest
  before_script:
    - source ci/variables/$CI_ENVIRONMENT_NAME
    - apt-get update
    - apt install -y groff
    - pip install awscli
  script:
    - cd src/personalize/zip
    - ls -lrt
    - aws s3 cp ./ s3://$CI_ENVIRONMENT_NAME-$BUCKET_NAME_SUFFIX/ --recursive  --exclude "*" --include="*.zip"
  tags:
    - docker
    - ops

playground:upload_zip:
  extends: .upload_zip
  stage: deploy
  dependencies:
    - build_zip
  environment:
    name: playground

```

To avoid having the need to run `terraform apply` every time you make  change to lambdas and upload a brand new set of zips, we should change above pipeline to update lambda with new zips:

```yml
.update_lambdas:
  image: python:latest
  before_script:
    - source ci/variables/$CI_ENVIRONMENT_NAME
    - apt-get update
    - apt install -y groff
    - pip install awscli
  script:
    - cd src/personalize/scripts
    - sh update_lambda.sh $CI_ENVIRONMENT_NAME`
  tags:
    - docker
    - ops
```

update lambda aws cli command:

`aws lambda update-function-code --function-name playground-create-schema --s3-bucket playground-personalize-lambda --s3-key createschema.zip`


`update_lambda.sh`

```sh

lambdaNamesSuffixes=(
    "create-schema"
    "create-dataset"
    "create-datasetgroup"
    "create-dataset-importjob"
    "create-solution"
    "create-solution-version"
    "create-campaign"
    "update-campaign"
    "notify"
    "trigger-state-machine"
)

for i in "${lambdaNamesSuffixes[@]}"; do
    aws lambda get-function --function-name $1-$i

    if [ $? -ne 0 ]
        aws lambda update-function-code --function-name playground-create-schema --s3-bucket playground-personalize-lambda --s3-key createschema.zip
    then
        
    fi
done

```


`update_lambdas.py`

```python
import boto3
import json
import sys

LAMBDA = boto3.client('lambda')

lambdaNamesSuffixes=(
    "create-schema",
    "create-dataset",
    "create-datasetgroup",
    "create-dataset-importjob",
    "create-solution",
    "create-solution-version",
    "create-campaign",
    "update-campaign",
    "notify",
    "trigger-state-machine",
)

if __name__ == "__main__":
    lambdaPrefix = sys.argv[1] #environment name

    for lambdaSuffix in lambdaNamesSuffixes:
        try:
            response = LAMBDA.get_function(FunctionName=lambdaPrefix+ lambdaSuffix,Qualifier='string')
            lambdaArn = response['Configuration']['FunctionArn']

            response = client.update_function_code(
                FunctionName=lambdaPrefix+ lambdaSuffix,
                S3Bucket=lambdaPrefix+"-personalize-lambda"
                S3Key=lambdaSuffix.replace('-', '')
            )

        except:
            pass
    


```

This let's you simplify your lambda tf code to this:

```sh
resource "aws_lambda_function" "create-schema" {
  s3_bucket     = "${aws_s3_bucket.personalize-lambda.bucket}"
  s3_key        = "createschema.zip"
  function_name = "${lower(var.environment_tag)}-create-schema"
  description   = "Creates a schema in personalize"
  handler       = "createschema.lambda_handler"
  runtime       = "python3.7"

  kms_key_arn = "${data.aws_kms_key.env-kms.arn}"
  role        = "${aws_iam_role.lambda-role.arn}"
  timeout     = 30
  memory_size = 1216
  layers      = ["${aws_lambda_layer_version.lambda_layer.arn}"]

  vpc_config {
    subnet_ids         = ["${data.aws_subnet_ids.lambda-subnet-ids.ids}"]
    security_group_ids = ["${data.aws_security_group.erewhon_lambda_sg.id}"]
  }

  environment {
    variables = {
      ENV = "${upper(var.environment_tag)}"
    }
  }

  tags = {
    Name        = "${lower(var.environment_tag)}-create-schema"
    environment = "${lower(var.environment_tag)}"
    team        = "aoshima"
  }
}
```

