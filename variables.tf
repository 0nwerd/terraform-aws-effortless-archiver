variable "name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "schedule_expression" {
  description = "Schedule expression for the CloudWatch Event Rule"
  type        = string
  default     = "rate(2 hours)"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to export to"
  type        = string
}

variable "ledger_name" {
  description = "Name of the QLDB ledger to export (Optional)"
  type        = string
  default     = null
}

variable "qldb_key_arn" {
  description = "ARN of the KMS key to use for encryption for QLDB (Optional)"
  type        = string
  default     = null
}

variable "vpc_subnet_ids" {
  description = "List of subnet IDs when the function should run in a VPC (Optional)"
  type        = list(string)
  default     = null
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs when the function should run in a VPC (Optional)"
  type        = list(string)
  default     = null
}
