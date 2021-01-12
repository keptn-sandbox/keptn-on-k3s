#!/bin/bash

K8S_DOMAIN=${K8S_DOMAIN:-none}

if [[ "$K8S_DOMAIN" == "none" ]]; then
    echo "No Domain has been passed, getting it from the api-Ingress"
    KEPTN_K8S_DOMAIN=$(kubectl get ing -n keptn api-keptn-ingress -o=jsonpath='{.spec.rules[0].host}')
    K8S_DOMAIN=${KEPTN_K8S_DOMAIN/#keptn.}
    echo "Domain: $K8S_DOMAIN"
else 
    echo "Domain has been passed: $K8S_DOMAIN"  
fi

#Default values
GIT_USER="keptn"
GIT_PASSWORD="keptn#R0cks"
GIT_SERVER="http://git.$K8S_DOMAIN"

# static vars
GIT_TOKEN="keptn-upstream-token"
TOKEN_FILE=$GIT_TOKEN.json

echo "Username: $GIT_USER"
echo "Password: $GIT_PASSWORD"
echo "GIT-Server: $GIT_SERVER" 