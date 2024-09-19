# Dockerfile

# Use an official Python runtime as a parent image
FROM python:3.12-slim

ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /app

# Install dependencies
RUN pip install poetry
RUN poetry install

# Copy the current directory contents into the container at /app
COPY . /app/


# Run migrations, collect static files and start the Django server with Gunicorn bound to port 80
CMD ["sh", "-c", "python manage.py migrate && python manage.py collectstatic --noinput"]
