#!/usr/bin/env bash

set -eu

PREFIX="https"

KEPTN_CONTROL_PLANE_DOMAIN=${KEPTN_CONTROL_PLANE_DOMAIN:-none}
KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN=${KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN:-none}

if [[ "$KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN" == "none" ]] || [[ "$KEPTN_CONTROL_PLANE_DOMAIN" == "none" ]]; then
  echo "Script needs control plain domain set in KEPTN_CONTROL_PLANE_DOMAIN, e.g: abc12345.cloudautomation.live.dynatrace.com"
  echo "Script needs execution plane ingress domain set in KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN, e.g: your.local.i.p.nip.io"
  exit 1
fi

export KEPTN_ENDPOINT="${PREFIX}://${KEPTN_CONTROL_PLANE_DOMAIN}"
export KEPTN_INGRESS="${KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN}"

currentDir=pwd
cd ../..
./create-keptn-project-from-template.sh prod-delivery-simplenode ${OWNER_EMAIL} delivery-demo
cd 