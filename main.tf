terraform {
  required_providers {
    aws = {
      version = "3.4.0"
    }
  }
}

module "lambda" {
  source  = "armorfret/lambda/aws"
  version = "0.0.4"

  source_bucket  = var.source_bucket
  source_version = var.source_version
  function_name  = var.function_name

  environment_variables = var.environment_variables

  access_policy_document = var.access_policy_document

  source_arns = ["${aws_api_gateway_rest_api.this.execution_arn}/*"]
}

module "certificate" {
  source    = "armorfret/acm-certificate/aws"
  version   = "0.1.13"
  hostnames = [var.hostname]
}

resource "aws_api_gateway_rest_api" "this" {
  name = var.function_name
}

resource "aws_api_gateway_method" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_deployment.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.this.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda.invoke_arn
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_method.this,
    aws_api_gateway_method.root,
    aws_api_gateway_integration.this,
    aws_api_gateway_integration.root,
    aws_api_gateway_resource.this,
  ]

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = "prod"
  variables   = var.stage_variables
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{path+}"
}

resource "aws_api_gateway_domain_name" "this" {
  domain_name     = var.hostname
  certificate_arn = module.certificate.arn
}

resource "aws_api_gateway_base_path_mapping" "this" {
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_deployment.this.stage_name
  domain_name = aws_api_gateway_domain_name.this.domain_name
}

