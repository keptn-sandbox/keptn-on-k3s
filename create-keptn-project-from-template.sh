#!/usr/bin/env bash

# Usage: create-keptn-project-from-template.sh quality-gate-dynatrace yourname@email.com quality-gate demo

TEMPLATE_DIRECTORY="keptn_project_templates"

# Parameters for Script
TEMPLATE_NAME=${1:-none}
OWNER_EMAIL=${2:-none}
PROJECT_NAME=${3:-none}
SERVICE_NAME=${4:-none}


# Expected Env Variables that should be set!
# KEPTN_ENDPOINT="https://yourkeptndomain.abc
KEPTN_BRIDGE_PROJECT="${KEPTN_ENDPOINT}/bridge/project/${PROJECT_NAME}"
KEPTN_BRIDGE_PROJECT_ESCAPED="${KEPTN_BRIDGE_PROJECT//\//\\/}"


if [[ "$TEMPLATE_NAME" == "none" ]]; then
    echo "You have to set TEMPLATE_NAME to a template keptn project name such as quality-gate-dynatrace. You find all available templates in the ${TEMPLATE_DIRECTORY} directory"
    echo "Usage: $0 quality-gate-dynatrace yourname@email.com quality-gate demo"
    exit 1
fi
if [[ "$OWNER_EMAIL" == "none" ]]; then
    echo "You have to set OWNER_EMAIL to a valid email as this might be used in e.g: Dynatrace Dashboards .."
    echo "Usage: $0 quality-gate-dynatrace yourname@email.com quality-gate demo"
    exit 1
fi

if [[ "$PROJECT_NAME" == "none" ]]; then
    echo "You have to set PROJECT_NAME to the project name you want to create based on the template"
    echo "Usage: $0 quality-gate-dynatrace yourname@email.com quality-gate demo"
    exit 1
fi

if ! [ -x "$(command -v tree)" ]; then
    echo "Tree command not installed. This is required"
    exit 1
fi

if ! [ -x "$(command -v keptn)" ]; then
    echo "Keptn CLI is not installed. This is required"
    exit 1
fi

# Validate that keptn cli is successfull authenticated
if keptn status | grep -q "Successfully authenticated"; then
    echo "Keptn CLI connected successfully!"
else 
    echo "Keptn CLI not authenticated. Please authenticate first and then run script again"
    exit 1
fi 

# Validate that the keptn project doesnt already exist
if keptn get project $PROJECT_NAME | grep -q "No project"; then
    echo "Validated that Keptn Project $PROJECT_NAME doesnt yet exist. Continue creation of project"
else
    echo "Keptn Project $PROJECT_NAME already exists. Please specify a different project name of delete existing project first"
    exit 1
fi 

# Validate that there is a template directory that we can use to create projects from
if ! [ -d "${TEMPLATE_DIRECTORY}" ]; then
    echo "Can't find Keptn Project Template: ${TEMPLATE_DIRECTORY}"
    exit 1
fi

# Validate that the specific project template exists
if ! [ -d "${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}" ]; then
    echo "Can't find Keptn Project Template: ${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}"
    exit 1
fi

# Validate that the specific project template has a shipyard
if ! [ -f "${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}/shipyard.yaml" ]; then
    echo "Keptn Project Template doesnt have a shipyard.yaml: ${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}/shipyard.yaml"
    exit 1
fi

# switch to template directory
currDir=$(pwd)
echo "Switching to Template Directory"
cd "${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}"

#
# Now lets create that Keptn project
#
echo "Create Keptn Project: ${PROJECT_NAME} from ${TEMPLATE_NAME}"
keptn create project "${PROJECT_NAME}" --shipyard=./shipyard.yaml

#
# Validate that project was created
if keptn get project $PROJECT_NAME | grep -q "No project"; then
    echo "Create Project failed or not finished yet. Waiting for 5 seconds and trying this again."
    sleep 5
    if keptn get project $PROJECT_NAME | grep -q "No project"; then
        echo "Create Project failed. Aborting creation of project. Please check your Keptn installation"
        exit 1
    fi 
fi 

#
# Now lets create a service if specified
#
if ! [[ "$SERVICE_NAME" == "none" ]]; then
    echo "Create Keptn Project: ${PROJECT_NAME} from ${TEMPLATE_NAME}"
    keptn create service $SERVICE_NAME --project="${PROJECT_NAME}"
else
    SERVICE_NAME=""
fi

#
# Now we iterate through the template folder and add all resources on project level
#
for localFileName in $(tree -i -f)
do 
    # if this is a directory we dont do anything! if its not a valid file we also skip it
    if [ -d "$localFileName" ]; then continue; fi
    if ! [ -f "$localFileName" ]; then continue; fi

    # we are not re-uploading the shipyard.yaml nor do we iterate through the service_template subdirectories
    if [[ "${localFileName}" == *"shipyard.yaml"* ]]; then continue; fi

    # if its a file in a stage_STAGENAME directory lets add this to the STAGE_NAME
    RESOURCE_STAGE_NAME=""
    REMOVE_FROM_REMOTE_FILENAME=""
    if [[ "${localFileName}" == *"/stage_"* ]]; then 
      RESOURCE_STAGE_NAME=$(echo "${localFileName##*/stage_}")
      RESOURCE_STAGE_NAME=$(echo "${RESOURCE_STAGE_NAME%%/*}")
      REMOVE_FROM_REMOTE_FILENAME="stage_${RESOURCE_STAGE_NAME}"
      echo $REMOVE_FROM_REMOTE_FILENAME
    fi

    # if its a file in a service_template directory lets add to the service SERVICE_NAME
    if [[ "${localFileName}" == *"service_template"* ]]; then 
      RESOURCE_SERVICE_NAME=$SERVICE_NAME
    else
      RESOURCE_SERVICE_NAME=""
    fi

    #
    # create a tmp file so we can do any IN-FILE replacements
    cp ${localFileName} ${localFileName}.tmp
    sed -i "s/\${REPLACE_KEPTN_BRIDGE}/${KEPTN_BRIDGE_PROJECT_ESCAPED}/" ${localFileName}.tmp
    sed -i "s/\${REPLACE_OWNER_EMAIL}/${OWNER_EMAIL}/" ${localFileName}.tmp

    #
    # Create remote file name, e.g: replace any filename placeholders and remove leading ./
    remoteFileName=$(echo "${localFileName/.\//}")
    remoteFileName=$(echo "${localFileName/service_template/}")
    remoteFileName=$(echo "${remoteFileName/$REMOVE_FROM_REMOTE_FILENAME/}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_PROJECT/$PROJECT_NAME}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_STAGE/$STAGE_NAME}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_SERVICE/$SERVICE_NAME}")

    # echo "Processing localFileName: ${localFileName}"
    # echo "Using remoteFileName: ${remoteFileName}"
    keptn add-resource --project="${PROJECT_NAME}" --stage="${RESOURCE_STAGE_NAME}" --service="${RESOURCE_SERVICE_NAME}" --resource="${localFileName}.tmp" --resourceUri="${remoteFileName}"

    # remove tmp file
    rm ${localFileName}.tmp
done 

# switch back to prev working dir
cd "${currDir}"