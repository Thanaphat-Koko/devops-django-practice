#!/bin/sh

echo "Run Postgres.................................."
kubectl apply -f ./k8s/postgres-deployment.yaml
echo "Run Django-Web....................................."
kubectl apply -f ./k8s/django-deployment.yaml
echo "Run Nginx-WebServer.................................."
kubectl apply -f ./k8s/nginx-deployment.yaml