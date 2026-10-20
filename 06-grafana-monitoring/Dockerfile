# Not in the original exercise, but its Jenkinsfile runs
# `docker build -t delivery_metrics .`, which needs a Dockerfile.
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY delivery_metrics.py .
EXPOSE 8000
CMD ["python", "delivery_metrics.py"]
