from flask import Flask
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
import os

# Configure OpenTelemetry with resource attributes
resource = Resource(
    attributes={
        "service.name": "flask-dd-otel-app",  # Custom service name for Datadog
        "service.version": "1.0.0",           # Optional
        "deployment.environment": "development"  # Optional
    }
)

# Set up tracer provider
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer_provider = trace.get_tracer_provider()
tracer_provider.add_span_processor(
    BatchSpanProcessor(
        OTLPSpanExporter(endpoint="http://localhost:4317")  # Datadog Agent OTLP endpoint
    )
)

# Initialize Flask app
app = Flask(__name__)
FlaskInstrumentor.instrument_app(app)

# Example route
@app.route('/')
def hello():
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span("example-span"):
        return 'Hello, World! Datadog OTEL Tracing'

# Additional route for testing
@app.route('/test')
def test():
    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span("test-span"):
        return 'Test Route for Tracing'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)