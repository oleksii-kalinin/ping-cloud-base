#!/bin/bash

cd /Users/kyryloyermak/Documents/dev/ping-cloud/ping-cloud-docker/pingcloud-monitoring/enrichment-bootstrap

docker build --no-cache -t 7es7/enrichment-bootstrap:pdo-5647_1 .
docker push 7es7/enrichment-bootstrap:pdo-5647_1

kubectl delete sts logstash-elastic
kubectl apply -f /Users/kyryloyermak/Documents/dev/ping-cloud/ping-cloud-base/k8s-configs/cluster-tools/base/logging/elastic-stack/logstash/logstash.yaml