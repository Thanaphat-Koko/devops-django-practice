#!/bin/sh

echo "Show library list................................."
poetry show
echo "Check environment info............................"
poetry env info
poetry show gunicorn
echo "Run Server........................................"
poetry run which gunicorn
poetry run gunicorn project_jrd.wsgi:application --bind 0.0.0.0:8000