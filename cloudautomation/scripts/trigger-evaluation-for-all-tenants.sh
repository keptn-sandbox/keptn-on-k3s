#!/usr/bin/env bash

set -eu

TENANTS=${1:-none}
PROJECT=${2:-none}
STAGE=${3:-none}
TIMEFRAME=${4:-none}
SLEEP_IN_SECS=${5:-5}

if [[ "$TENANTS" == "none" ]] || [[ "$PROJECT" == "none" ]] || [[ "$STAGE" == "none" ]] || [[ "$TIMEFRAME" == "none" ]]; then
  echo "Usage: ./$0 TENANTLIST PROJECT STAGE TIMEFRAME [SLEEP_IN_SECS]"
  echo "Example: "
  echo "./$0 tenants.sh dynatrace quality-gate 30m"
  exit 1
fi

# loading tenants
source $TENANTS

instanceCount=${#INSTANCE_ARRAY[@]}

# now either create a single or multiple instances
for (( instanceIx=0; instanceIx<instanceCount; instanceIx++ ))
do
    INSTANCE_NAME=${INSTANCE_ARRAY[$instanceIx]}

    keptn trigger evaluation --project=$2 --stage=$3 --service=tnt-$INSTANCE_NAME-svc --timeframe=$4

    sleep $SLEEP_IN_SECS
done