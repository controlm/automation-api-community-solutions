#!/bin/bash
#
# Delete failed objects
#
echo These objects will be deleted
kubectl get $1 | grep Error
kubectl get $1 | grep Error | cut -d' ' -f 1 | xargs kubectl delete $1