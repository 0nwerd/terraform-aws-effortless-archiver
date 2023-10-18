data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${abspath(path.cwd)}/lambda/lambda.py"
  output_path = "${abspath(path.cwd)}/lambda/lambda.zip"
}

data "aws_iam_policy_document" "logs_exporter_policy" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateExportTask", "logs:Describe*", "logs:ListTagsLogGroup"]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:DescribeParameters", "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:PutParameter"]
    resources = ["arn:aws:ssm:${var.region}:${var.account_id}:parameter/log-exporter-last-export/*", ]
  }

  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:ssm:${var.region}:${var.account_id}:parameter/log-exporter-last-export/*", ]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:PutObjectACL"]
    resources = ["arn:aws:s3:::${var.s3_bucket_arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutBucketAcl", "s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.s3_bucket_arn}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["qldb:ExportJournalToS3"]
    resources = ["arn:aws:qldb:${var.region}:${var.account_id}:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [module.qldb_export_task_role.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.qldb_key_arn]
  }
}

//Add a role for lambda
// CREATE AN IAM ROLE FOR THE EXPORT TASKS

resource "aws_iam_role_policy" "logs_exporter_policy" {
  name_prefix = "log-exporter"
  role        = module.logs_exporter_role.id
  policy      = data.aws_iam_policy_document.logs_exporter_policy.json
}

//Add modular security group

resource "aws_lambda_function" "logs_exporter_lambda" {
  function_name    = "CloudWatchLogsExporter"
  description      = "Export CloudWatch Logs to a S3 bucket"
  role             = null
  handler          = "lambda.lambda_handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 300

  runtime = "python3.8"

  environment {
    variables = {
      S3_BUCKET   = var.s3_bucket_arn
      AWS_ACCOUNT = var.account_id
      EXPORT_ROLE_ARN = module.qldb_export_task_role.arn
      LEDGER_NAME     = var.ledger_name
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [""] : [] # One block if var.vpc_subnets is not empty
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [module.logs_exporter_lambda_sg.id]
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/CloudWatchLogsExporter"
  retention_in_days = var.cloudwatch_retention
  kms_key_id        = var.cloudwatch_logs_key
}

resource "aws_cloudwatch_event_rule" "logs_exporter_rule" {
  name_prefix         = "logs-exporter"
  description         = "Fires periodically to export logs to S3"
  schedule_expression = "rate(4 hours)"
}

resource "aws_cloudwatch_event_target" "logs_exporter_target" {
  target_id = "logs-exporter"
  rule      = aws_cloudwatch_event_rule.logs_exporter_rule.name
  arn       = aws_lambda_function.logs_exporter_lambda.arn
}

resource "aws_lambda_permission" "log_exporter" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.logs_exporter_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.logs_exporter_rule.arn
}
