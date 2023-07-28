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

variable "binary_media_types" {
  description = "Media types to transmit as binary data"
  type        = list(string)
  default     = []
}

variable "access_policy_document" {
  description = "IAM policy provided to Lambda role"
  type        = string
}

variable "hostname" {
  description = "Hostname to use for site"
  type        = string
}

variable "auth_source_bucket" {
  description = "Bucket to use for loading Auth Lambda source ZIP"
  type        = string
  default     = ""
}

variable "auth_source_version" {
  description = "Version of Auth Lambda ZIP to use"
  type        = string
  default     = null
}

variable "auth_environment_variables" {
  description = "Variables to provide for Auth Lambda environment"
  type        = map(string)
  default     = {}
}

variable "auth_access_policy_document" {
  description = "IAM policy provided to Auth Lambda role"
  type        = string
  default     = null
}

variable "auth_ttl" {
  description = "Cache time for authorizer check"
  type        = number
  default     = 300
}

variable "kms_key_arn" {
  description = "Use custom KMS key for Cloudwatch logs"
  type        = string
  default     = ""
}
