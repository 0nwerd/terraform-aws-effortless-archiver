variable "name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to export to"
  type        = string
}
