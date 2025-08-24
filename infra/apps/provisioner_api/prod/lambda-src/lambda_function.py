import base64
import gzip
import json
import os
import urllib.request
import urllib.parse

def lambda_handler(event, context):
    """
    CloudWatch Logs to Datadog forwarder
    Enhanced version to handle all log types properly
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

    try:
        # Process CloudWatch Logs
        cw_data = event['awslogs']['data']
        cw_logs = json.loads(gzip.decompress(base64.b64decode(cw_data)))

        # Transform logs for Datadog
        dd_logs = []
        for log_event in cw_logs['logEvents']:
            # Extract timestamp
            timestamp = log_event['timestamp']

            # Try to parse as JSON first, fallback to raw message
            message = log_event['message'].strip()
            parsed_message = None

            try:
                # Try to parse as JSON
                parsed_message = json.loads(message)
            except (json.JSONDecodeError, ValueError):
                # Not JSON, use raw message
                parsed_message = message

            # Create base Datadog log entry
            dd_log = {
                'timestamp': timestamp,
                'message': parsed_message,
                'ddsource': dd_source,
                'service': 'resource-provisioner-api',  # Default service
                'ddtags': dd_tags,
                'aws': {
                    'awslogs': {
                        'logGroup': cw_logs['logGroup'],
                        'logStream': cw_logs['logStream'],
                        'owner': cw_logs['owner']
                    }
                }
            }

            # If it's a structured log, extract additional metadata
            if isinstance(parsed_message, dict):
                # Extract log level if present
                if 'level' in parsed_message:
                    dd_log['level'] = parsed_message['level']

                # Extract service if present
                if 'service' in parsed_message:
                    dd_log['service'] = parsed_message['service']

                # Add any additional fields as tags
                additional_tags = []
                for key, value in parsed_message.items():
                    if key not in ['message', 'level', 'time', 'timestamp']:
                        additional_tags.append(f"{key}:{value}")

                if additional_tags:
                    existing_tags = dd_log['ddtags']
                    if existing_tags:
                        dd_log['ddtags'] = f"{existing_tags},{','.join(additional_tags)}"
                    else:
                        dd_log['ddtags'] = ','.join(additional_tags)

            dd_logs.append(dd_log)

        # Send to Datadog in batches if needed
        batch_size = 100  # Datadog recommended batch size
        for i in range(0, len(dd_logs), batch_size):
            batch = dd_logs[i:i + batch_size]

            # Create payload
            payload = '\n'.join([json.dumps(log) for log in batch])

            # Prepare request
            headers = {
                'Content-Type': 'text/plain',
                'DD-API-KEY': api_key
            }

            # Compress if payload is large
            data = payload.encode('utf-8')
            if len(data) > 1000:
                data = gzip.compress(data)
                headers['Content-Encoding'] = 'gzip'

            req = urllib.request.Request(
                dd_url,
                data=data,
                headers=headers,
                method='POST'
            )

            response = urllib.request.urlopen(req)

            if response.status != 200:
                print(f"WARNING: Unexpected response status: {response.status}")

            print(f"Successfully forwarded batch of {len(batch)} logs to Datadog")

        return {
            'statusCode': 200,
            'body': f'Successfully forwarded {len(dd_logs)} logs to Datadog in {(len(dd_logs) + batch_size - 1) // batch_size} batches'
        }

    except Exception as e:
        print(f"ERROR: Failed to forward logs to Datadog: {str(e)}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        return {
            'statusCode': 500,
            'body': f'Error forwarding logs: {str(e)}'
        }
