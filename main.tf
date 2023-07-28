terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "lambda" {
  source  = "armorfret/lambda/aws"
  version = "0.3.1"

  source_bucket  = var.source_bucket
  source_version = var.source_version
  function_name  = var.function_name

  environment_variables = var.environment_variables

  access_policy_document = var.access_policy_document

  source_arns = ["${aws_api_gateway_rest_api.this.execution_arn}/*"]
}

module "certificate" {
  source    = "armorfret/acm-certificate/aws"
  version   = "0.3.1"
  hostnames = [var.hostname]
}

resource "aws_api_gateway_rest_api" "this" {
  name = var.function_name

  binary_media_types = var.binary_media_types
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  depends_on = [
    aws_api_gateway_method.root,
    aws_api_gateway_integration.root,
    aws_api_gateway_method.this,
    aws_api_gateway_integration.this,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name = "${var.function_name}-apigw"

  kms_key_id = var.kms_key_arn == "" ? null : var.kms_key_arn
}

resource "aws_api_gateway_stage" "this" {
  deployment_id        = aws_api_gateway_deployment.this.id
  rest_api_id          = aws_api_gateway_rest_api.this.id
  stage_name           = "prod"
  variables            = var.stage_variables
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.this.arn
    format = jsonencode({
      authorizeResultStatus    = "$context.authorize.status"
      authorizerLatency        = "$context.authorizer.latency"
      authorizerRequestId      = "$context.authorizer.requestId"
      authorizerServiceStatus  = "$context.authorizer.status"
      caller                   = "$context.identity.caller"
      cognitoUser              = "$context.identity.cognitoIdentityId"
      extendedRequestId        = "$context.extendedRequestId"
      functionResponseStatus   = "$context.integration.status"
      httpMethod               = "$context.httpMethod"
      integrationLatency       = "$context.integration.latency"
      integrationRequestId     = "$context.integration.requestId"
      integrationServiceStatus = "$context.integration.integrationStatus"
      ip                       = "$context.identity.sourceIp"
      path                     = "$context.path"
      principalId              = "$context.authorizer.principalId"
      protocol                 = "$context.protocol"
      requestId                = "$context.requestId"
      requestTime              = "$context.requestTime"
      resourcePath             = "$context.resourcePath"
      responseLatency          = "$context.responseLatency"
      responseLength           = "$context.responseLength"
      status                   = "$context.status"
      user                     = "$context.identity.user"
      userAgent                = "$context.identity.userAgent"
      xrayTraceId              = "$context.xrayTraceId"
    })
  }
}

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_api_gateway_domain_name" "this" {
  domain_name     = var.hostname
  certificate_arn = module.certificate.arn
  security_policy = "TLS_1_2"
}

resource "aws_api_gateway_base_path_mapping" "this" {
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  domain_name = aws_api_gateway_domain_name.this.domain_name
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{path+}"
}

resource "aws_api_gateway_method" "this" { #tfsec:ignore:aws-api-gateway-no-public-access
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "ANY"
  authorization = var.auth_source_bucket == "" ? "NONE" : "CUSTOM"
  authorizer_id = var.auth_source_bucket == "" ? null : aws_api_gateway_authorizer.this[0].id
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.this.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda.invoke_arn
}

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = var.auth_source_bucket == "" ? "NONE" : "CUSTOM"
  authorizer_id = var.auth_source_bucket == "" ? null : aws_api_gateway_authorizer.this[0].id
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda.invoke_arn
}

resource "aws_api_gateway_authorizer" "this" {
  name                             = "authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  authorizer_uri                   = module.auth_lambda[0].invoke_arn
  authorizer_result_ttl_in_seconds = var.auth_ttl
  count                            = var.auth_source_bucket == "" ? 0 : 1
}

module "auth_lambda" {
  source  = "armorfret/lambda/aws"
  version = "0.3.1"
  count   = var.auth_source_bucket == "" ? 0 : 1

  source_bucket  = var.auth_source_bucket
  source_version = var.auth_source_version
  function_name  = "${var.function_name}_auth"

  environment_variables = var.auth_environment_variables

  access_policy_document = var.auth_access_policy_document

  source_arns = ["${aws_api_gateway_rest_api.this.execution_arn}/*"]
}
