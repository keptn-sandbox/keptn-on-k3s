#!/usr/bin/env bash

set -eu

TENANTS=${1:-none}
PROJECT=${2:-none}

if [[ "$TENANTS" == "none" ]] || [[ "$PROJECT" == "none" ]] ; then
  echo "Usage: $0 TENANTLIST PROJECT"
  echo "Example: "
  echo "$0 tenants.sh lab1"
  exit 1
fi

# loading tenants
source $TENANTS

instanceCount=${#INSTANCE_ARRAY[@]}

# now either create a single or multiple instances
for (( instanceIx=0; instanceIx<instanceCount; instanceIx++ ))
do
    TENANT_ID=${INSTANCE_ARRAY[$instanceIx]}

    monaco -e ../monaco/environment.yaml -p $PROJECT ../monaco/projects
done