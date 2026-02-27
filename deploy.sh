#!/bin/bash
echo "Deploying Boutique Microservices to OpenShift..."
kubectl apply -f base/
echo "Deployment complete. Use 'oc get pods' to check status."
