#!/bin/bash
# Function file for adding created keptn repos to a self-hosted git repository

source ./gitea-functions.sh

# get Tokens for the User
getApiTokens

# create an Api Token
createApiToken

# read the Token and keep the hash in memory
readApiTokenFromFile

# create a repo for each keptn project and migrate it.
createKeptnRepos