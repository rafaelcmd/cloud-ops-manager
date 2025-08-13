import json
import base64
import gzip
import urllib3
import os
from datetime import datetime

def lambda_handler(event, context):
    """
    Forward CloudWatch logs to Datadog
    """

    # Datadog configuration
    dd_api_key = os.environ['DD_API_KEY']
    dd_site = os.environ.get('DD_SITE', 'datadoghq.com')
    dd_source = os.environ.get('DD_SOURCE', 'aws')
    dd_tags = os.environ.get('DD_TAGS', '')

    # Datadog logs endpoint
    dd_url = f"https://http-intake.logs.{dd_site}/v1/input/{dd_api_key}"

    http = urllib3.PoolManager()

    # Process CloudWatch logs event
    cw_data = event['awslogs']['data']
    cw_logs = json.loads(gzip.decompress(base64.b64decode(cw_data)))

    log_events = []

    for log_event in cw_logs['logEvents']:
        # Format log for Datadog
        formatted_log = {
            'timestamp': log_event['timestamp'],
            'message': log_event['message'],
            'ddsource': dd_source,
            'ddtags': dd_tags,
            'service': extract_service_from_log_group(cw_logs['logGroup']),
            'aws': {
                'awslogs': {
                    'logGroup': cw_logs['logGroup'],
                    'logStream': cw_logs['logStream'],
                    'owner': cw_logs['owner']
                }
            }
        }
        log_events.append(formatted_log)

    # Send to Datadog
    try:
        response = http.request(
            'POST',
            dd_url,
            body=json.dumps(log_events).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'DD-API-KEY': dd_api_key
            }
        )

        print(f"Sent {len(log_events)} logs to Datadog. Status: {response.status}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully forwarded {len(log_events)} logs to Datadog'
            })
        }

    except Exception as e:
        print(f"Error forwarding logs to Datadog: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Failed to forward logs: {str(e)}'
            })
        }

def extract_service_from_log_group(log_group_name):
    """
    Extract service name from CloudWatch log group name
    """
    if '/ecs/' in log_group_name:
        return log_group_name.split('/ecs/')[-1]
    elif '/aws/lambda/' in log_group_name:
        return log_group_name.split('/aws/lambda/')[-1]
    else:
        return log_group_name.replace('/', '-')
