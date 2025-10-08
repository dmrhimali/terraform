import json
from datadog_lambda.metric import lambda_metric  # For custom metrics
from ddtrace import tracer  # For tracing/custom spans
import time  # Example import; trace as needed

@tracer.wrap()  # Auto-wraps the function for tracing
def lambda_handler(event, context):
    # Get current span for tags (e.g., for business logic)
    current_span = tracer.current_span()
    if current_span:
        current_span.set_tag('custom.tag', 'value')  # Add tags to Lambda span

    # Example: Custom span
    with tracer.trace("custom.operation") as span:
        span.set_tag('operation.type', 'example')
        time.sleep(0.1)  # Simulate work

    # Example: Submit custom metric (async, no overhead)
    lambda_metric(
        metric_name='myapp.order_value',
        value=42.99,
        tags=['env:prod', 'service:my-lambda']
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from instrumented Lambda!')
    }