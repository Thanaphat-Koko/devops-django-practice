# Dockerfile

# Use an official Python runtime as a parent image
FROM python:3.12.10-alpine3.21

ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

# Install dependencies
RUN apk update && apk add --no-cache \
    libpq-dev gcc python3-dev build-base

RUN pip install --no-cache-dir -r requirements.txt

ENV POETRY_VIRTUALENVS_IN_PROJECT=true

RUN poetry update

RUN poetry install --no-root -v
# RUN poetry run python manage.py migrate
# RUN poetry run python manage.py collectstatic --noinput

