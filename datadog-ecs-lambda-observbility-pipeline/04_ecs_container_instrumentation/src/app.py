from flask import Flask
import random
import logging
from ddtrace import tracer

from ddtrace import patch_all
patch_all()  # Instruments Flask automatically

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route('/')
def hello():
    with tracer.start_span('custom-hello-span'):
        logger.info("Handling hello request")
        return f"Hello, ECS Fargate! Random number: {random.randint(1, 100)}"

@app.route('/health')
def health():
    return "OK"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)