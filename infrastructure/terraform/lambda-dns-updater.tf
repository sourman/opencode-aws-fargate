resource "aws_iam_role" "lambda_dns_updater" {
  name = "${var.project_name}-lambda-dns-updater-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_dns_updater" {
  name = "${var.project_name}-lambda-dns-updater-policy"
  role = aws_iam_role.lambda_dns_updater.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${local.zone_id}",
          "arn:aws:route53:::change/*"
        ]
      }
    ]
  })
}

data "archive_file" "lambda_dns_updater" {
  type        = "zip"
  output_path = "${path.module}/lambda-dns-updater.zip"
  source {
    content = <<EOF
import json
import boto3
import os

ecs = boto3.client('ecs')
ec2 = boto3.client('ec2')
route53 = boto3.client('route53')

CLUSTER_NAME = os.environ['CLUSTER_NAME']
SERVICE_NAME = os.environ['SERVICE_NAME']
ZONE_ID = os.environ['ZONE_ID']
RECORD_NAME = os.environ['RECORD_NAME']

def lambda_handler(event, context):
    try:
        task_arn = event.get('detail', {}).get('taskArn')
        
        if not task_arn:
            list_response = ecs.list_tasks(
                cluster=CLUSTER_NAME,
                serviceName=SERVICE_NAME
            )
            if not list_response['taskArns']:
                print("No tasks found")
                return {'statusCode': 200, 'body': 'No tasks found'}
            task_arn = list_response['taskArns'][0]
        
        describe_response = ecs.describe_tasks(
            cluster=CLUSTER_NAME,
            tasks=[task_arn]
        )
        
        if not describe_response['tasks']:
            print("Task not found")
            return {'statusCode': 200, 'body': 'Task not found'}
        
        task = describe_response['tasks'][0]
        
        if task['lastStatus'] != 'RUNNING':
            print(f"Task not running: {task['lastStatus']}")
            return {'statusCode': 200, 'body': f"Task status: {task['lastStatus']}"}
        
        attachment = next(
            (a for a in task.get('attachments', []) if a['type'] == 'ElasticNetworkInterface'),
            None
        )
        
        if not attachment:
            print("No network interface found")
            return {'statusCode': 200, 'body': 'No network interface found'}
        
        network_interface_id = next(
            (d['value'] for d in attachment['details'] if d['name'] == 'networkInterfaceId'),
            None
        )
        
        if not network_interface_id:
            print("Network interface ID not found")
            return {'statusCode': 200, 'body': 'Network interface ID not found'}
        
        ni_response = ec2.describe_network_interfaces(
            NetworkInterfaceIds=[network_interface_id]
        )
        
        if not ni_response['NetworkInterfaces']:
            print("Network interface not found")
            return {'statusCode': 200, 'body': 'Network interface not found'}
        
        public_ip = ni_response['NetworkInterfaces'][0].get('Association', {}).get('PublicIp')
        
        if not public_ip:
            print("No public IP found")
            return {'statusCode': 200, 'body': 'No public IP found'}
        
        print(f"Updating DNS record {RECORD_NAME} to {public_ip}")
        
        route53.change_resource_record_sets(
            HostedZoneId=ZONE_ID,
            ChangeBatch={
                'Changes': [{
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': RECORD_NAME,
                        'Type': 'A',
                        'TTL': 60,
                        'ResourceRecords': [{'Value': public_ip}]
                    }
                }]
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'DNS updated to {public_ip}',
                'ip': public_ip
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "dns_updater" {
  filename         = data.archive_file.lambda_dns_updater.output_path
  function_name    = "${var.project_name}-dns-updater"
  role            = aws_iam_role.lambda_dns_updater.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      CLUSTER_NAME = aws_ecs_cluster.main.name
      SERVICE_NAME = aws_ecs_service.opencode.name
      ZONE_ID      = local.zone_id
      RECORD_NAME  = aws_route53_record.agent.fqdn
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_dns_updater" {
  name              = "/aws/lambda/${aws_lambda_function.dns_updater.function_name}"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "ecs_task_state" {
  name        = "${var.project_name}-ecs-task-state-change"
  description = "Trigger DNS updater when ECS tasks change state"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [aws_ecs_cluster.main.arn]
      lastStatus = ["RUNNING", "STOPPED"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda_dns_updater" {
  rule      = aws_cloudwatch_event_rule.ecs_task_state.name
  target_id = "UpdateDNS"
  arn       = aws_lambda_function.dns_updater.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dns_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_task_state.arn
}

