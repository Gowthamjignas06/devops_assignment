FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# The original copies ex3-flash-sale.py, but gunicorn loads "app:app",
# so the file must be named app.py.
COPY app.py .
CMD ["gunicorn","-b","0.0.0.0:5000","app:app","--workers","1","--threads","2"]
