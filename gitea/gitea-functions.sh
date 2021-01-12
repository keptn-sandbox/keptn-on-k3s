#!/bin/bash
# Gitea Documentation
# https://gitea.com/gitea/helm-chart/#configuration

# Load git vars
source ./gitea-vars.sh

# Create Token
createApiToken(){
    echo "Creating token for $GIT_USER from $GIT_SERVER"
    curl -v --user $GIT_USER:$GIT_PASSWORD \
    -X POST "$GIT_SERVER/api/v1/users/$GIT_USER/tokens" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8" \
    -d "{ \"name\": \"$GIT_TOKEN\" }" -o $TOKEN_FILE
}

getApiTokens(){
    echo "Get tokens for $GIT_USER from $GIT_SERVER"
    curl -v --user $GIT_USER:$GIT_PASSWORD \
    -X GET "$GIT_SERVER/api/v1/users/$GIT_USER/tokens" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8"
}

deleteApiToken(){
    echo "Deleting token for $GIT_USER from $GIT_SERVER"
    curl -v --user $GIT_USER:$GIT_PASSWORD \
    -X DELETE "$GIT_SERVER/api/v1/users/$GIT_USER/tokens/$TOKEN_ID" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8" 
}

readApiTokenFromFile() {
    if [ ! -f "$TOKEN_FILE" ]; then
        createApiToken 
    fi 

    if [ -f "$TOKEN_FILE" ]; then
        echo "Reading token from file $TOKEN_FILE"
        TOKENJSON=$(cat $TOKEN_FILE)
        API_TOKEN=$(echo $TOKENJSON | jq -r '.sha1')
        TOKEN_ID=$(echo $TOKENJSON | jq -r '.id')
        echo "tokenId: $TOKEN_ID hash: $API_TOKEN"
    else 
        echo "Cant get Git Token!"
    fi
}

createKeptnRepos() {
    echo "Creating repositories for Keptn projects "
    for project in `keptn get projects | awk '{ if (NR!=1) print $1}'`;
    do 
        createKeptnRepo $project
    done
}

updateKeptnRepo(){
    KEPTN_PROJECT=$1
    keptn update project $KEPTN_PROJECT --git-user=$GIT_USER --git-token=$API_TOKEN --git-remote-url=$GIT_SERVER/$GIT_USER/$KEPTN_PROJECT.git
}

createKeptnRepoManually(){
    readApiTokenFromFile
    createKeptnRepo $1
}

createKeptnRepo(){
    echo "Creating and migrating Keptn project to self-hosted git for $1"
    createGitRepo $1
    updateKeptnRepo $1
}

createGitRepo(){
    echo "Create repo for project $1"
    # Create Repo with Token
    curl -X POST "$GIT_SERVER/api/v1/user/repos?access_token=$API_TOKEN" \
    -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{ \"auto_init\": false, \"default_branch\": \"master\", \"name\": \"$1\", \"private\": false}"
}

echo "gitea functions have been loaded"

return
