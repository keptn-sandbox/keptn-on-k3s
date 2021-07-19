#!/usr/bin/env bash

set -eu

TENANTS=${1:-none}
PROJECT=${2:-none}
STAGE=${3:-none}
IMAGE=${4:-none}
SLEEP_IN_SECS=${5:-20}

if [[ "$TENANTS" == "none" ]] || [[ "$PROJECT" == "none" ]] || [[ "$STAGE" == "none" ]] || [[ "$IMAGE" == "none" ]]; then
  echo "Usage: ./trigger-for-all-tenants.sh TENANTLIST PROJECT STAGE IMAGE [SLEEP_IN_SECS]"
  echo "Example: "
  echo "./trigger-for-all-tenants.sh tenants.sh delivery-demo production grabnerandi/simplenodeservice:3.0.0"
  exit 1
fi

# loading tenants
source $TENANTS

instanceCount=${#INSTANCE_ARRAY[@]}

# now either create a single or multiple instances
for (( instanceIx=0; instanceIx<instanceCount; instanceIx++ ))
do
    INSTANCE_NAME=${INSTANCE_ARRAY[$instanceIx]}

    keptn trigger delivery --project=$2 --stage=$3 --service=tnt-$INSTANCE_NAME-svc --image=$4

    sleep $SLEEP_IN_SECS
done