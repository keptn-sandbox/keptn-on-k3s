#!/usr/bin/env bash

# Usage: create-keptn-project-from-template.sh quality-gate-dynatrace quality-gate demo

TEMPLATE_DIRECTORY="keptn_project_templates"

TEMPLATE_NAME=${1:-none}
PROJECT_NAME=${2:-none}
SERVICE_NAME=${3:-none}

if [[ "$TEMPLATE_NAME" == "none" ]]; then
    echo "You have to set TEMPLATE_NAME to a template keptn project name such as quality-gate-dynatrace. You find all available templates in the ${TEMPLATE_DIRECTORY} directory"
    echo "Usage: $0 quality-gate-dynatrace quality-gate demo"
    exit 1
fi
if [[ "$PROJECT_NAME" == "none" ]]; then
    echo "You have to set PROJECT_NAME to the project name you want to create based on the template"
    echo "Usage: $0 quality-gate-dynatrace quality-gate demo"
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
# Now we iterate through the template folder and add all resources on project level
#
for tempFile in $(tree -i -f)
do 
    echo "tempFile: ${tempFile}"
    # if this is a directory we dont do anything!
    if [ -d "$tempFile" ]; then continue; fi;

    # we are not re-uploading the shipyard.yaml nor do we iterate through the service_template subdirectories
    if [[ "${localFileName}" == *"shipyard.yaml"* ]]; then continue; fi
    if [[ "${localFileName}" == *"service_template"* ]]; then continue; fi

    echo "Processing localFileName: ${localFileName}"

    # TODO - replace placeholders within FILES, e.g: PROJECT_NAME, STAGE_NAME, SERVICE_NAME, KEPTNS_BRIDGE_URL ...
    remoteFileName=$(echo "${localFileName/.\//}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_PROJECT_NAME/$PROJECT_NAME}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_STAGE_NAME/$STAGE_NAME}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_SERVICE_NAME/$SERVICE_NAME}")

    echo "Using remoteFileName: ${remoteFileName}"

    # is this file for a specific stage?
    if [[ "${localFileName}" == *"stage_"** ]]; then
        # TODO parse the name of the stage from the stage_STAGENAME/filename
        keptn add-resource --project="${PROJECT_NAME}" --stage="${STAGE_NAME}" --resource="${localFileName}" --resourceUri="${remoteFileName}"

    else 
        keptn add-resource --project="${PROJECT_NAME}" --resource="${localFileName}" --resourceUri="${remoteFileName}"
    fi; 
done 

#
# Now lets create the service if a SERVICE_NAME was given
#
if ! [[ "$SERVICE_NAME" == "none" ]]; then
    echo "Create Keptn Service: ${SERVICE_NAME}"
    keptn create service "${SERVICE_NAME}" --project="${PROJECT_NAME}"

    # Now we iterate through the template folder for services and add all resources on service level
    for tempFile in $(tree -i -f)
    do 
        # remove the trailing ./${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME} of the tree output
        localFileName=$(echo "${tempFile/.\${TEMPLATE_DIRECTORY}\/${TEMPLATE_NAME}\//}")

        # we are only interested in the service_template subdirectory
        if [[ "${localFileName}" == *"service_template"* ]]; then

            echo "Processing localFileName: ${tempFile}"

            # TODO - replace placeholders within FILES, e.g: PROJECT_NAME, STAGE_NAME, SERVICE_NAME, KEPTNS_BRIDGE_URL ...
            remoteFileName=$(echo "${localFileName/.\//}")
            remoteFileName=$(echo "${remoteFileName/KEPTN_PROJECT_NAME/$PROJECT_NAME}")
            remoteFileName=$(echo "${remoteFileName/KEPTN_STAGE_NAME/$STAGE_NAME}")
            remoteFileName=$(echo "${remoteFileName/KEPTN_SERVICE_NAME/$SERVICE_NAME}")

            echo "Using remoteFileName: ${remoteFileName}"

            keptn add-resource --project="${PROJECT_NAME}" --service="${SERVICE_NAME}" --resource="${localFileName}" --resourceUri="${remoteFileName}"
        fi

    done 

fi


# switch back to prev working dir
cd "${currDir}"