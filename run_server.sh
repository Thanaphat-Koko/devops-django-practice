#!/bin/sh

echo "Show library list................................."
poetry show
echo "Run Server........................................"
poetry run gunicorn project_jrd.wsgi:application --bind 0.0.0.0:8000