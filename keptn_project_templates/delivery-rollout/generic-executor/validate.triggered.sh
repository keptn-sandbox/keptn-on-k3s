#!/bin/bash

# This is a script that will be executed by the Keptn Generic Executor Service
# It will be called with a couple of enviornment variables that are filled with Keptn Event Details, Env-Variables from the Service container as well as labels

if [[ "$DATA_VALIDATE_WAITTIME" == "" ]]; then
  DATA_VALIDATE_WAITTIME="10s"
fi 

echo "Validate Triggered Script for $DATA_PROJECT.$DATA_STAGE.$DATA_SERVICE"
echo "We are simply waiting for the passed time: $DATA_VALIDATE_WAITTIME"

sleep "$DATA_VALIDATE_WAITTIME"

if [[ "$DATA_DEPLOYMENT_DEPLOYMENTURISPUBLIC_0" != "" ]]; then
  echo "And now we validate whether we can reach the deployment Url: $DATA_DEPLOYMENT_DEPLOYMENTURISPUBLIC_0"
  wget "$DATA_DEPLOYMENT_DEPLOYMENTURISPUBLIC_0" -q -O /dev/null
  echo "wget returned $?"
fi