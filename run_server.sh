#!/bin/sh

echo "Show library list................................."
poetry show
echo "Check environment info............................"
poetry env info
echo "Run which poetry................................"
poetry run which poetry
poetry --version
echo "Run show gunicorn................................."
poetry show gunicorn
echo "Run which gunicorn................................"
poetry run which gunicorn
echo "Run Server........................................"
poetry shell
gunicorn project_jrd.wsgi:application --bind 0.0.0.0:8000