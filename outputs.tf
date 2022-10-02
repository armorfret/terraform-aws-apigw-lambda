output "dns_name" {
  value = aws_api_gateway_domain_name.this.cloudfront_domain_name
}

output "execution_arn" {
  value = aws_api_gateway_stage.this.execution_arn
}
