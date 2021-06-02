#!/bin/bash

# This is a script that will be executed by the Keptn Generic Executor Service
# It will be called with a couple of enviornment variables that are filled with Keptn Event Details, Env-Variables from the Service container as well as labels

if [[ "$DATA_ECHO_MESSAGE" == "" ]]; then
  DATA_ECHO_MESSAGE="You didnt specify a message. So - I am just saying HI"
fi 

echo "Echo Triggered Script for $DATA_PROJECT.$DATA_STAGE.$DATA_SERVICE"
echo "-----------------------------------------------------------------"
echo "Your message: $DATA_ECHO_MESSAGE"