#!/bin/sh

poetry run python manage.py migrate
poetry run gunicorn project_jrd.wsgi:application --bind 0.0.0.0:80