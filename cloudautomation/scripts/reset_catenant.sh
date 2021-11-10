#!/usr/bin/env bash

# This script helps to reset a Cloud Automation tenant's default "dynatrace" project

set -eu

PREFIX="https"

KEPTN_CONTROL_PLANE_API_TOKEN=${KEPTN_CONTROL_PLANE_API_TOKEN:-none}
KEPTN_CONTROL_PLANE_DOMAIN=${KEPTN_CONTROL_PLANE_DOMAIN:-none}

if [[ "$KEPTN_CONTROL_PLANE_API_TOKEN" != "none" ]] && [[ "$KEPTN_CONTROL_PLANE_DOMAIN" != "none" ]]; then
  keptn auth --api-token "${KEPTN_CONTROL_PLANE_API_TOKEN}" --endpoint "${PREFIX}://$KEPTN_CONTROL_PLANE_DOMAIN/api"
else 
  # assume that keptn cli is already authenticated
  keptn status 
fi

echo "Ready to reset the currently connected keptn? (y/n)"
read userinput 
if [[ "$userinput" != "y" ]]; then
  echo "stop"
  exit 0
fi

# lets first delete secret and project
# keptn delete secret dynatrace
keptn delete project dynatrace

# now lets create the project and add the default dynatrace.conf.yaml
keptn create project dynatrace --shipyard=./dynatrace_shipyard.yaml
keptn add-resource --project=dynatrace --stage=quality-gate --resource="dynatrace.conf.quality-gate.yaml" --resourceUri="dynatrace/dynatrace.conf.yaml"
# keptn add-resource --project=dynatrace --stage=production --resource="dynatrace.conf.production.yaml" --resourceUri="dynatrace/dynatrace.conf.yaml"
