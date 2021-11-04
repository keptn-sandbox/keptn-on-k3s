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

# change into the monaco directory
currentDir=$(pwd)
cd ../monaco

# now call monaco
for (( instanceIx=0; instanceIx<instanceCount; instanceIx++ ))
do
    TENANT_ID=${INSTANCE_ARRAY[$instanceIx]}

    if [[ "$PROJECT" == "delete" ]]; then
      sed -e 's~TENANT_ID~'"$TENANT_ID"'~' \
        projects/delete/delete.tmpl > projects/delete/delete.yaml
      monaco -e environment.yaml projects/delete
      rm projects/delete/delete.yaml
    else 
      monaco -e environment.yaml -p $PROJECT projects
    fi

done

# and now back
cd $currentDir