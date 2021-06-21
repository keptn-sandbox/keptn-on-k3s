#!/bin/bash

# This is a script that will be executed by the Keptn Generic Executor Service
# It will be called with a couple of enviornment variables that are filled with Keptn Event Details, Env-Variables from the Service container as well as labels

echo "GetJoke Triggered Script for $DATA_PROJECT.$DATA_STAGE.$DATA_SERVICE"
echo "-----------------------------------------------------------------"
wget -O- "https://official-joke-api.appspot.com/random_joke"