#!/usr/bin/env bash

set -eu

PREFIX="https"

KEPTN_CONTROL_PLANE_DOMAIN=${KEPTN_CONTROL_PLANE_DOMAIN:-none}
KEPTN_CONTROL_PLANE_API_TOKEN=${KEPTN_CONTROL_PLANE_API_TOKEN:-none}
KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN=${KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN:-none}

if [[ "$KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN" == "none" ]] || [[ "$KEPTN_CONTROL_PLANE_DOMAIN" == "none" ]] || [[ "$KEPTN_CONTROL_PLANE_API_TOKEN" == "none" ]]; then
  echo "Script needs control plain domain set in KEPTN_CONTROL_PLANE_DOMAIN, e.g: abc12345.cloudautomation.live.dynatrace.com"
  echo "Script needs execution plane ingress domain set in KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN, e.g: your.local.i.p.nip.io"
  echo "Script needs keptn API token set in KEPTN_CONTROL_PLANE_API_TOKEN"
  exit 1
fi

export KEPTN_ENDPOINT="${PREFIX}://${KEPTN_CONTROL_PLANE_DOMAIN}"
export KEPTN_INGRESS="${KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN}"

# allow specifying the tenants.sh file as first parameter
TENANTSFILE=${1:-none}
if [[ "$TENANTSFILE" == "none"  ]]; then 
  TENANTSFILE = "./cloudautomation/scripts/tenants.sh"
fi 


currentDir=$(pwd)
cd ../..

echo "Lets create delivery-demo project"
./create-keptn-project-from-template.sh prod-delivery-simplenode ${OWNER_EMAIL} delivery-demo ${TENANTSFILE}

echo "Lets create release-validation project"
./create-keptn-project-from-template.sh release-validation-simplenode ${OWNER_EMAIL} release-validation ${TENANTSFILE}

echo "Lets create devopstools project"
./create-keptn-project-from-template.sh prod-devopstools ${OWNER_EMAIL} devopstools

cd ${currentDir}