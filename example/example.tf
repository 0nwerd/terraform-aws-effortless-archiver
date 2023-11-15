data "aws_caller_identity" "current" {}

module "example" {
  source = "../"

  name       = "example"
  region     = "us-east-1"
  account_id = data.aws_caller_identity.current.account_id

  s3_bucket_arn = "YOUR_BUCKET_ARN"
}