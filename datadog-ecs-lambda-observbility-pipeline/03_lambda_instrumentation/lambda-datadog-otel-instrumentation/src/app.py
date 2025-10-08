import json
from datadog_lambda.metric import lambda_metric  # Keep for custom metrics
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
import time

# Initialize OTel tracer (outside handler for reuse)
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

def lambda_handler(event, context):
    # Wrap handler in a span (replaces @tracer.wrap())
    with tracer.start_as_current_span("lambda.handler") as span:
        # Add custom attribute (replaces current_span.set_tag)
        span.set_attribute("custom.tag", "value")

        # Custom span for specific operation
        with tracer.start_as_current_span("custom.operation") as custom_span:
            custom_span.set_attribute("operation.type", "example")
            time.sleep(0.1)  # Simulate work

        # Submit custom metric (unchanged; works with Datadog extension)
        lambda_metric(
            metric_name="myapp.order_value",
            value=42.99,
            tags=["env:prod", "service:my-lambda"]
        )

        return {
            "statusCode": 200,
            "body": json.dumps("Hello from instrumented Lambda!")
        }