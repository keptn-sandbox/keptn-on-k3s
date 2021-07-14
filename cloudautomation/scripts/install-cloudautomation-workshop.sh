#!/usr/bin/env bash

set -eu

PREFIX="https"

KEPTN_CONTROL_PLANE_DOMAIN=${KEPTN_CONTROL_PLANE_DOMAIN:-none}
KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN=${KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN:-none}

if [[ "$KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN" == "none" ]] || [[ "$KEPTN_CONTROL_PLANE_DOMAIN" == "none" ]]; then
  echo "Script needs control plain domain set in KEPTN_CONTROL_PLANE_DOMAIN"
  echo "Script needs execution plane ingress domain set in KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN"
  exit 1
fi

export KEPTN_ENDPOINT="${PREFIX}://${KEPTN_CONTROL_PLANE_DOMAIN}"
export KEPTN_INGRESS="${KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN}"

currentDir=pwd
cd ../..
./create-keptn-project-from-template.sh prod-delivery-simple ${OWNER_EMAIL} prod-delivery-simple
cd 