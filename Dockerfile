# Dockerfile

# Use an official Python runtime as a parent image
FROM python:3.12-slim

ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app/

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev gcc python3-dev build-essential
RUN pip install poetry
RUN poetry install

# Run migrations, collect static files and start the Django server with Gunicorn bound to port 80
CMD ["sh", "-c", "python manage.py migrate && python manage.py collectstatic --noinput"]
