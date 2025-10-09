FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/app.py .

EXPOSE 8000

# Run with Datadog auto-instrumentation
CMD ["ddtrace-run", "gunicorn", "--bind", "0.0.0.0:8000", "app:app"]