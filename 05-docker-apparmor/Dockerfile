# Use an official Python runtime as a parent image
# (python:3.8-slim in the original is end-of-life)
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Install Flask
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application into the container at /app
COPY app.py /app/

# Expose port 5000
EXPOSE 5000

# Run app.py when the container launches
CMD ["python", "app.py"]
