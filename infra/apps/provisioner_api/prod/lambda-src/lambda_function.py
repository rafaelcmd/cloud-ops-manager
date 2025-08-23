import base64
import gzip
import json
import os
import urllib.request
import urllib.parse

# Datadog log intake URL
DD_URL = "https://http-intake.logs.datadoghq.com/v1/input/"

def lambda_handler(event, context):
    """
    CloudWatch Logs to Datadog forwarder
    """
    # Get Datadog API key from environment
    api_key = os.environ.get('DD_API_KEY')
    if not api_key:
        print("ERROR: DD_API_KEY environment variable not set")
        return {'statusCode': 400, 'body': 'Missing DD_API_KEY'}

    # Get other environment variables
    dd_site = os.environ.get('DD_SITE', 'datadoghq.com')
    dd_source = os.environ.get('DD_SOURCE', 'aws')
    dd_tags = os.environ.get('DD_TAGS', '')

    # Construct Datadog URL
    dd_url = f"https://http-intake.logs.{dd_site}/v1/input/{api_key}"

    # Process CloudWatch Logs
    cw_data = event['awslogs']['data']
    cw_logs = json.loads(gzip.decompress(base64.b64decode(cw_data)))

    # Transform logs for Datadog
    dd_logs = []
    for log_event in cw_logs['logEvents']:
        # Parse JSON logs if possible, otherwise use raw message
        try:
            message = json.loads(log_event['message'])
        except (json.JSONDecodeError, KeyError):
            message = log_event['message']

        # Create Datadog log entry
        dd_log = {
            'timestamp': log_event['timestamp'],
            'message': message,
            'ddsource': dd_source,
            'ddtags': dd_tags,
            'aws.awslogs.logGroup': cw_logs['logGroup'],
            'aws.awslogs.logStream': cw_logs['logStream'],
            'aws.awslogs.owner': cw_logs['owner']
        }
        dd_logs.append(dd_log)

    # Send to Datadog
    try:
        payload = '\n'.join([json.dumps(log) for log in dd_logs])

        req = urllib.request.Request(
            dd_url,
            data=payload.encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'Content-Encoding': 'gzip' if len(payload) > 1000 else 'identity'
            }
        )

        # Compress if payload is large
        if len(payload) > 1000:
            req.data = gzip.compress(req.data)

        response = urllib.request.urlopen(req)

        print(f"Successfully forwarded {len(dd_logs)} logs to Datadog")
        return {
            'statusCode': 200,
            'body': f'Successfully forwarded {len(dd_logs)} logs'
        }

    except Exception as e:
        print(f"ERROR: Failed to forward logs to Datadog: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error forwarding logs: {str(e)}'
        }
