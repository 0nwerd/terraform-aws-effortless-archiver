locals {
  eventbridge_rules_payload = [
    "{ \"export_type\": \"logs\" }",
    "{ \"export_type\": \"qldb\" }"
  ]
}

###############
# Lambda role #
###############
data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name_prefix         = "${var.name}_role"
  assume_role_policy  = data.aws_iam_policy_document.assume_role_lambda.json
  managed_policy_arns = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"] : null
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateExportTask", "logs:Describe*", "logs:ListTagsLogGroup"]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:DescribeParameters", "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:PutParameter"]
    resources = ["arn:aws:ssm:${var.region}:${var.account_id}:parameter/*", ]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutBucketAcl", "s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:PutObjectACL"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
  }

  dynamic "statement" {
    for_each = var.ledger_name != null ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["qldb:ExportJournalToS3"]
      resources = ["arn:aws:qldb:${var.region}:${var.account_id}:*"]
    }
  }

  dynamic "statement" {
    for_each = var.ledger_name != null ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = [module.qldb_export_role[0].arn]
    }
  }

  dynamic "statement" {
    for_each = var.qldb_key_arn != null ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [var.qldb_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name_prefix = "efforteless-archiver"
  role        = aws_iam_role.lambda_role.name
  policy      = data.aws_iam_policy_document.lambda_policy.json
}

####################
# QLDB export role #
####################
module "qldb_export_role" {
  source = "./modules/qldb_export_role"
  count  = var.ledger_name != null ? 1 : 0

  name          = var.name
  s3_bucket_arn = "arn:aws:s3:::${var.s3_bucket_name}"
}

###################
# Lambda function #
###################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda.py"
  output_path = "${path.module}/lambda/lambda.zip"
}

resource "aws_lambda_function" "lambda" {
  function_name    = var.name
  description      = "Export CloudWatch Logs (or QLDB Journal) to a S3 bucket"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda.lambda_handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 300

  runtime = "python3.8"

  environment {
    variables = {
      S3_BUCKET       = var.s3_bucket_name
      AWS_ACCOUNT     = var.account_id
      EXPORT_ROLE_ARN = var.ledger_name != null ? module.qldb_export_role[0].arn : null
      LEDGER_NAME     = var.ledger_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }
}

##################################
# Event Rule & Lambda Permission #
##################################
resource "aws_cloudwatch_event_rule" "event_rule" {
  count = length(local.eventbridge_rules_payload)

  name_prefix         = "efforteless-archiver"
  description         = "Fires periodically to launch export tasks"
  schedule_expression = var.schedule_expression

}

resource "aws_cloudwatch_event_target" "event_target" {
  count = length(local.eventbridge_rules_payload)

  target_id = "efforteless-archiver"
  rule      = aws_cloudwatch_event_rule.event_rule[count.index].name
  arn       = aws_lambda_function.lambda.arn
  input     = local.eventbridge_rules_payload[count.index]
}

resource "aws_lambda_permission" "lambda_permission" {
  count = length(local.eventbridge_rules_payload)

  statement_id  = "AllowExecutionFromCloudWatch_${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule[count.index].arn
}

####################
# S3 bucket Policy #
####################
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
  }

  statement {
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = var.s3_bucket_name
  policy = data.aws_iam_policy_document.bucket_policy.json
}
