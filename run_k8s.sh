#!/bin/sh

echo "Run Postgres.................................."
kubectl apply -f postgres-deployment.yaml
echo "Run Django-Web....................................."
kubectl apply -f django-deployment.yaml
echo "Run Nginx-WebServer.................................."
kubectl apply -f nginx-deployment.yaml