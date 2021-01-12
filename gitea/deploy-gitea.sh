#!/bin/bash

# Load git vars
K8S_DOMAIN=$1
source ./gitea-vars.sh

echo "Create namespace for git"
kubectl create ns git

sed -e 's~domain.placeholder~'"$K8S_DOMAIN"'~' \
    -e 's~GIT_USER.placeholder~'"$GIT_USER"'~' \
    -e 's~GIT_PASSWORD.placeholder~'"$GIT_PASSWORD"'~' \
    helm-gitea.yaml > gen/helm-gitea.yaml

echo "Install gitea via Helmchart"
helm install gitea gitea-charts/gitea -f gen/helm-gitea.yaml --namespace git

echo "Setup Gitea ingress"
cat gitea-ingress.yaml | sed 's~domain.placeholder~'"$K8S_DOMAIN"'~' > ./gen/gitea-ingress.yaml
kubectl apply -f gen/gitea-ingress.yaml