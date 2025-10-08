# terraform.tfvars
datadog_api_key = "99242b5ededcbbc2b41e69c9f28b6591"
datadog_app_key = "59efa3baa84790b9ac88eda26b84534d22010659"
datadog_site    = "us5.datadoghq.com"
environment     = "development"
function_name   = "my-datadog-instrumented-lambda"
runtime         = "python3.13"
lambda_handler  = "app.lambda_handler"