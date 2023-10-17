import boto3

from datetime import datetime
from os import environ
from time import time


ssm = boto3.client("ssm")
sts = boto3.client("sts")
logs = boto3.client("logs")
qldb = boto3.client("qldb")


def get_env_vars(env_var):
    if env_var not in environ:
        print(f"Error: {env_var} is not defined.")
        return False
    return environ[env_var]


def get_logs_groups():
    extra_args = {}
    log_groups = []

    while True:
        response = logs.describe_log_groups(**extra_args)
        for log_group in response["logGroups"]:
            log_groups.append(log_group["logGroupName"])

        if not "nextToken" in response:
            break

        extra_args["nextToken"] = response["nextToken"]

    return log_groups


def export_logs(log_group_name, ssm_parameter_name, ssm_value, export_to_time, max_retries, item, S3_BUCKET, AWS_ACCOUNT_ID):
    try:
        response = logs.create_export_task(
            logGroupName=log_group_name,
            fromTime=int(ssm_value),
            to=export_to_time,
            destination=S3_BUCKET,
            destinationPrefix=AWS_ACCOUNT_ID + "/" + item.strip("/")
        )

        ssm_response = ssm.put_parameter(
            Name=ssm_parameter_name,
            Type="String",
            Value=str(export_to_time),
            Overwrite=True
        )
        return 0

    except logs.exceptions.LimitExceededException:
        max_retries = max_retries - 1
        time.sleep(5)
        return max_retries

    except Exception as e:
        print(e)
        return 0


def export_qldb(LEDGER_NAME, S3_BUCKET, ssm_parameter_name, ssm_value, export_to_time, max_retries):
    try:
        # Launch the export to S3
        response = qldb.export_journal_to_s3(
            Name=LEDGER_NAME,
            InclusiveStartTime = datetime.fromtimestamp(int(ssm_value)/1000),
            ExclusiveEndTime = datetime.fromtimestamp(export_to_time/1000),
            S3ExportConfiguration = {
                'Bucket': S3_BUCKET,
                'Prefix': LEDGER_NAME + "/",
                'EncryptionConfiguration': {
                    'ObjectEncryptionType': 'SSE_S3'
                }
            },
            RoleArn=os.environ["EXPORT_ROLE_ARN"],
            OutputFormat='JSON'
        )

        # Update the last replication time
        ssm_response = ssm.put_parameter(
            Name=ssm_parameter_name,
            Type="String",
            Value=str(export_to_time),
            Overwrite=True,
        )
        
    except Exception as e:
        print(f"Error of replication : {e}")
    
    return 0


def lambda_handler(event, context):
    items = []

    S3_BUCKET = get_env_vars("S3_BUCKET")
    TIME = get_env_vars("TIME")

    if "LEDGER_NAME" in environ:
        export_type = "qldb"
        QLDB_LEDGER_NAME = get_env_vars("LEDGER_NAME")
        QLDB_EXPORT_ROLE_ARN = get_env_vars("EXPORT_ROLE_ARN")
        items.append(QLDB_LEDGER_NAME)
    else:
        export_type = "logs"
        AWS_ACCOUNT_ID = sts.get_caller_identity()["Account"]
        items = get_logs_groups()
    
    for item in items:
        ssm_parameter_name = (f"/{export_type}-last-export/{item}").replace("//", "/")
        try:
            ssm_request = ssm.get_parameter(Name=ssm_parameter_name)
            ssm_value = ssm_request["Parameter"]["Value"]
        except ssm.exceptions.ParameterNotFound:
            ssm_value = "0"

        export_time = int(round(time() * 1000))
        if (export_time - int(ssm_value)) < (int(TIME) * 1000):
            continue

        max_retries = 10
        while max_retries > 0:
            if export_type == "qldb":
                max_retries = export_qldb(item, S3_BUCKET, ssm_parameter_name, ssm_value, export_time, max_retries)
            else:
                max_retries = export_logs(item, ssm_parameter_name, ssm_value, export_time, max_retries, S3_BUCKET, AWS_ACCOUNT_ID)

            if max_retries == 0:
                break