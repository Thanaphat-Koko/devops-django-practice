# Use an official Python runtime as a parent image
FROM python:3.12-slim

ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app/

# Install dependencies
RUN apt-get update && apt-get install -y libpq-dev gcc python3-dev build-essential

RUN pip install --no-cache-dir -r requirements.txt
RUN poetry install

EXPOSE 80
RUN poetry run python manage.py collectstatic --noinput
RUN chmod +x ./run.sh
