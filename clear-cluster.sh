#!/bin/bash

# List of default K8s namespaces
DEFAULT_NS_LIST="default kube-node-lease kube-public kube-system this-is-kyryloyermak-primary-cluster"

# List of namepsaces to delete
DELETE_NS_LIST="argo-events elastic-stack-logging postgres-operator ping-cloud-kyryloyermak"

# Delete all cluster resources
kubectl delete -f /tmp/deploy.yaml

# Start proxy
kubectl proxy &

sleep 3

# Cleanup namespaces that have finalizers preventing them from being deleted
for ns in $DELETE_NS_LIST; do \
kubectl get ns $ns -o json | \
  jq '.spec.finalizers=[]' | \
  curl -X PUT http://localhost:8001/api/v1/namespaces/$ns/finalize -H "Content-Type: application/json" --data @-; done

# Stop proxy
pkill -9 -f "kubectl proxy"

# Cleanup CRDs that have finalizers preventing them from being deleted
for crd in $(kubectl get crd -o NAME); do kubectl patch $crd -p '{"metadata":{"finalizers":[]}}' --type=merge; done

# Compare actual namespaces list to default one
ACTUAL_NS_LIST=$(kubectl get ns -o NAME | cut -d "/" -f 2 | tr '\n' ' ')
diff <(echo $ACTUAL_NS_LIST | sort) <(echo $DEFAULT_NS_LIST | sort) 1>/dev/null

[[ $? -eq 0 ]] && echo "SUCCESS: Cluster was cleaned up." || echo "FAIL: Some errors occured while cluster cleaning up."