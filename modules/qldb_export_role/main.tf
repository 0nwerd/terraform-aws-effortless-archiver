data "aws_iam_policy_document" "assume_role_qldb" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["qldb.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "qldb_export_role" {
  name_prefix        = "${var.name}_qldb_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_qldb.json
}

data "aws_iam_policy_document" "qldb_export_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:PutObjectACL"]
    resources = [var.s3_bucket_arn]
  }
}

resource "aws_iam_role_policy" "qldb_export_task_policy" {
  name_prefix = "qldb-exporter"
  role        = aws_iam_role.qldb_export_role.name
  policy      = data.aws_iam_policy_document.qldb_export_policy.json
}
