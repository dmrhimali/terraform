



## Terraform

This project contains multiple terraform sscripts:

- [apm-newrelic-monitoring](apm-newrelic-monitoring)
- [aws-batch](aws-batch)
- [aws-emr-spark](aws-emr-spark)
- [aws-glue](aws-glue)
- [es-cloudwatch-monitoring](es-cloudwatch-monitoring)
- [es-newrelic-monitoring](es-newrelic-monitoring)
- 


## Gitlab pipeline to run terraform
**gitlab pipeline**

```yml
image: git.dmrh.com:4567/docker-images/terraform

stages:
- plan
- apply

.plan:
  before_script:
    - git clone https://ci_service:$CI_SERVICE_PASSWORD@bitbucket.dmrh.com/scm/far/terraform.git
    - git clone https://gitlab+deploy-token-2:$CI_VARS_DEPLOY_TOKEN@git.dmrh.com/operations/amazon-machine-images/ci-variables.git
    - source ci-variables/$env
    - cd terraform/environments/$env
    - echo "Environment:" $env
    - echo "Target to plan:" $TARGET
  script:
    - terraform init
    - terraform plan -target module.$TARGET -out=tfplan -lock=false -input=false
  only:
    variables:
      - $TARGET
  tags:
      - docker
      - ops

.apply:
  before_script:
    - git clone https://ci_service:$CI_SERVICE_PASSWORD@bitbucket.dmrh.com/scm/far/terraform.git tmp
    - git clone https://gitlab+deploy-token-2:$CI_VARS_DEPLOY_TOKEN@git.dmrh.com/operations/amazon-machine-images/ci-variables.git
    - mv tmp/* terraform/*
    - source ci-variables/$env
    - cd terraform/environments/$env
    - echo "Environment:" $env
    - echo "Applying Target:" $TARGET
  script:
    - terraform apply tfplan
  only:
    variables:
      - $TARGET
  tags:
      - docker
      - ops

LOCAL Plan:
  extends: .plan
  stage: plan
  variables:
    env: local
  when: manual
  artifacts:
    expire_in: 1h
    paths:
      - terraform/environments/$env/.terraform
      - terraform/environments/$env/tfplan

LOCAL Apply:
  extends: .apply
  stage: apply
  variables:
    env: local
  needs: ["LOCAL Plan"]
  dependencies:
    - LOCAL Plan
  when: manual

DEV Plan:
  extends: .plan
  stage: plan
  variables:
    env: dev
  when: manual
  artifacts:
    expire_in: 1h
    paths:
      - terraform/environments/$env/.terraform
      - terraform/environments/$env/tfplan

DEV Apply:
  extends: .apply
  stage: apply
  variables:
    env: dev
  needs: ["DEV Plan"]
  dependencies:
    - DEV Plan
  when: manual

QA Plan:
  extends: .plan
  stage: plan
  variables:
    env: qa
  when: manual
  artifacts:
    expire_in: 1h
    paths:
      - terraform/environments/$env/.terraform
      - terraform/environments/$env/tfplan

QA Apply:
  extends: .apply
  stage: apply
  variables:
    env: qa
  needs: ["QA Plan"]
  dependencies:
    - QA Plan
  when: manual


```



