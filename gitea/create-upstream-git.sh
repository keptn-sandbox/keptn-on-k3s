#!/bin/bash
# Function file for adding created keptn repos to a self-hosted git repository

if [[ -z "$1" ]]; then
  echo "You have to specify a project name, e.g: studentxxx"
  echo "Usage: $0 student001"
  exit 1
fi

source ./gitea-functions.sh

# read the Token and keep the hash in memory
readApiTokenFromFile

# create it for the passed project
createKeptnRepo $1