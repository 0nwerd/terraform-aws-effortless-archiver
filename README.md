## 📝 Medium Article
For more information about this module, check out this article: [https://medium.com/@louis-fiori/effortlessly-archive-cloudwatch-logs-or-qldb-journal-94700850ea6f](https://medium.com/@louis-fiori/effortlessly-archive-cloudwatch-logs-or-qldb-journal-94700850ea6f)

## 🔗 Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.2 |

## ➡️ Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account ID | `string` | n/a | yes |
| <a name="input_ledger_name"></a> [ledger\_name](#input\_ledger\_name) | Name of the QLDB ledger to export (Optional) | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Lambda function | `string` | n/a | yes |
| <a name="input_qldb_key_arn"></a> [qldb\_key\_arn](#input\_qldb\_key\_arn) | ARN of the KMS key to use for encryption for QLDB (Optional) | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | Name of the S3 bucket to export to | `string` | n/a | yes |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | Schedule expression for the CloudWatch Event Rule | `string` | `"rate(2 hours)"` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | List of security group IDs when the function should run in a VPC (Optional) | `list(string)` | `null` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs when the function should run in a VPC (Optional) | `list(string)` | `null` | no |

## ⬅️ Outputs

No outputs.
