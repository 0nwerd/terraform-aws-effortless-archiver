data "aws_caller_identity" "current" {}

module "example_logs" {
  source = "../"

  name       = "example_logs"
  region     = "us-east-1"
  account_id = data.aws_caller_identity.current.account_id

  s3_bucket_arn = "YOUR_BUCKET_ARN"
}

module "example_qldb" {
  source = "../"

  name       = "example_qldb"
  region     = "us-east-1"
  account_id = data.aws_caller_identity.current.account_id

  s3_bucket_arn = "YOUR_BUCKET_ARN"
  ledger_name   = "YOUR_LEDGER_NAME"
}
