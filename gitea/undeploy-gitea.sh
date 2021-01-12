#!/bin/bash -x

# clean up
helm del gitea --namespace gitea
kubectl delete ns gitea