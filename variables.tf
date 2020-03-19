variable "source_bucket" {
  description = "Bucket to use for loading Lambda source ZIP"
  type        = string
}

variable "source_version" {
  description = "Version of Lambda ZIP to use"
  type        = string
}

variable "function_name" {
  description = "Name for Lambda function"
  type        = string
}

variable "environment_variables" {
  description = "Variables to provide for Lambda environment"
  type        = map(string)
  default     = {}
}

variable "stage_variables" {
  description = "Variables to provide for API Gateway environment"
  type        = map(string)
  default     = {}
}

variable "access_policy_document" {
  description = "IAM policy provided to Lambda role"
  type        = string
}

variable "hostname" {
  description = "Hostname to use for site"
  type        = string
}

