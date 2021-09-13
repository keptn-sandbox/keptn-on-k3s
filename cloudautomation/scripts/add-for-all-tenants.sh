#!/usr/bin/env bash

set -eu

TENANTS=${1:-none}
PROJECT=${2:-none}
STAGE=${3:-none}
RESOURCE=${4:-none}
RESOURCEURI=${5:-none}

if [[ "$TENANTS" == "none" ]] || [[ "$PROJECT" == "none" ]] || [[ "$STAGE" == "none" ]] || [[ "$RESOURCE" == "none" ]] || [[ "$RESOURCEURI" == "none" ]]; then
  echo "Usage: ./add-for-all-tenants.sh TENANTLIST PROJECT STAGE RESOURCE RESOURCEURI"
  echo "Example: "
  echo "./add-for-all-tenants.sh tenants.sh delivery-demo production slo.yaml dynatrace/slo.yaml"
  exit 1
fi

# loading tenants
source $TENANTS

instanceCount=${#INSTANCE_ARRAY[@]}

# now either create a single or multiple instances
for (( instanceIx=0; instanceIx<instanceCount; instanceIx++ ))
do
    INSTANCE_NAME=${INSTANCE_ARRAY[$instanceIx]}

    keptn add-resource --project=$2 --stage=$3 --service=tnt-$INSTANCE_NAME-svc --resource=$RESOURCE --resourceUri=$RESOURCEURI

    sleep 1
done