#!/usr/bin/env bash

set -eu

TENANTS=${1:-none}
PROJECT=${2:-none}
STAGE=${3:-none}
LOCALRESOURCE=${4:-none}
RESOURCEURI=${5:-none}

if [[ "$TENANTS" == "none" ]] || [[ "$PROJECT" == "none" ]] || [[ "$STAGE" == "none" ]] || [[ "$LOCALRESOURCE" == "none" ]] || [[ "$RESOURCEURI" == "none" ]]; then
  echo "Usage: $0 TENANTLIST PROJECT STAGE SERVICE LOCALRESOURCE RESOURCEURI"
  echo "Example: "
  echo "$0 tenants.sh delivery-demo production localslo.yaml slo.yaml"
  exit 1
fi

# loading tenants
source $TENANTS

instanceCount=${#INSTANCE_ARRAY[@]}

# now either create a single or multiple instances
for (( instanceIx=0; instanceIx<instanceCount; instanceIx++ ))
do
    INSTANCE_NAME=${INSTANCE_ARRAY[$instanceIx]}

    keptn add-resource --project=$2 --stage=$3 --service=tnt-$INSTANCE_NAME-svc --resource=$4 --resourceUri=$5
done