#!/usr/bin/env bash

# Usage: create-keptn-project-from-template.sh project-template-folder yourname@email.com new-project-name
#        create-keptn-project-from-template.sh quality-gate-dynatrace myuser@gmail.com quality-gate

# Here is a sample project-template-folder folder structure with the explanation what will happen
# project-template-folder\
#   shipyard.yaml           --> this is the only MANDATORY file. it will be the shipyard for keptn create project
#   dynatrace\
#     dynatrace.conf.yaml   --> will be uploaded to the project level
#   service_demo            --> if a foler with service_ exists it will either create or onboard a new service depending on whether there is a subfolder charts
#     charts                --> if the charts subfolder exists it will do a keptn onboard service demo --charts=./charts otherwise keptn create service
#   stage_quality-gate      --> this folder will be iterated and content will be uploaded to the quality-gate stage
#     dynatrace\
#       dynatrace.conf.yaml --> this will now be a stage specific file
#     demo\                 
#       jmeter\
#         jmeter.conf.yaml  --> this file will be a jmeter.conf.yaml specific to the demo service in the quality-gate stage

# The files in the repo can contain certain PLACEHOLDERS which will be replaced before uploaded. 
# The replacement happens in .tmp files - so - no original files will be changed. Here the list of REPLACE options
# REPLACE_KEPTN_BRIDGE         with -> KEPTN_BRIDGE_PROJECT_ESCAPED
# REPLACE_OWNER_EMAIL          with -> OWNER_EMAIL
# REPLACE_KEPTN_INGRESS        with -> KEPTN_INGRESS
# REPLACE_SYNTHETIC_LOCATION   with -> SYNTHETIC_LOCATION (defaults to GEOLOCATION-45AB48D9D6925ECC)
# REPLACE_KEPTN_PROJECT        with -> Keptn Project Name

# default template project directory
TEMPLATE_DIRECTORY="keptn_project_templates"

# Parameters for Script - they have to be passed to the script!
TEMPLATE_NAME=${1:-none}
OWNER_EMAIL=${2:-none}
PROJECT_NAME=${3:-none}
SYNTHETIC_LOCATION=${SYNTHETIC_LOCATION:-GEOLOCATION-45AB48D9D6925ECC}

INSTANCE_COUNT_XXX=${4:-1}

# Expected Env Variables that should be set!
# KEPTN_ENDPOINT="https://keptn.yourkeptndomain.abc
# KEPTN_INGRESS="yourkeptndomain.abc"
KEPTN_BRIDGE_PROJECT="${KEPTN_ENDPOINT}/bridge/project/${PROJECT_NAME}"
KEPTN_BRIDGE_PROJECT_ESCAPED="${KEPTN_BRIDGE_PROJECT//\//\\/}"

if [[ "$TEMPLATE_NAME" == "none" ]]; then
    echo "You have to set TEMPLATE_NAME to a template keptn project name such as quality-gate-dynatrace. You find all available templates in the ${TEMPLATE_DIRECTORY} directory"
    echo "Usage: $0 project-template-folder youremail@domain.com new-project-name"
    echo "Example: $0 quality-gate-dynatrace myname@email.com quality-gate"
    exit 1
fi
if [[ "$OWNER_EMAIL" == "none" ]]; then
    echo "You have to set OWNER_EMAIL to a valid email as this might be used in e.g: Dynatrace Dashboards .."
    echo "Usage: $0 project-template-folder youremail@domain.com new-project-name"
    echo "Example: $0 quality-gate-dynatrace myname@email.com quality-gate"
    exit 1
fi

if [[ "$PROJECT_NAME" == "none" ]]; then
    echo "You have to set PROJECT_NAME to the project name you want to create based on the template"
    echo "Usage: $0 project-template-folder youremail@domain.com new-project-name"
    echo "Example: $0 quality-gate-dynatrace myname@email.com quality-gate"
    exit 1
fi

if [[ "$KEPTN_ENDPOINT" == "" ]]; then
    echo "You have to export KEPTN_ENDPOINT and set it to your Keptn Endpoint URL, e.g: https://keptn.yourkeptndomain.com"
    echo "Its needed when e.g: creating Dynatrace dashboards that point back to the Keptn Bridge"
    exit 1
fi

if [[ "$KEPTN_INGRESS" == "" ]]; then
    echo "You have to export KEPTN_INGRESS and set it to your Ingress host , e.g: yourkeptndomain.com"
    echo "Its needed when e.g: creating Dynatrace dashboards that point back to the Keptn Bridge"
    exit 1
fi

## Now - lets validate if all tools are installed that are needed
if ! [ -x "$(command -v tree)" ]; then
    echo "Tree command not installed. This is required"
    exit 1
fi

if ! [ -x "$(command -v keptn)" ]; then
    echo "Keptn CLI is not installed. This is required"
    exit 1
fi

## Validate that keptn cli is successfull authenticated
if keptn status | grep -q "Successfully authenticated"; then
    echo "Keptn CLI connected successfully!"
else 
    echo "Keptn CLI not authenticated. Please authenticate first and then run script again"
    exit 1
fi 

## Validate that the keptn project doesnt already exist
if keptn get project $PROJECT_NAME | grep -q "No project"; then
    echo "Validated that Keptn Project $PROJECT_NAME doesnt yet exist. Continue creation of project"
else
    echo "Keptn Project $PROJECT_NAME already exists. Please specify a different project name of delete existing project first"
    exit 1
fi 

## Validate that there is a template directory that we can use to create projects from
if ! [ -d "${TEMPLATE_DIRECTORY}" ]; then
    echo "Can't find Keptn Project Template: ${TEMPLATE_DIRECTORY}"
    exit 1
fi

## Validate that the specific project template exists
if ! [ -d "${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}" ]; then
    echo "Can't find Keptn Project Template: ${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}"
    exit 1
fi

## Validate that the specific project template has a shipyard
if ! [ -f "${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}/shipyard.yaml" ]; then
    echo "Keptn Project Template doesnt have a shipyard.yaml: ${TEMPLATE_DIRECTORY}/${TEMPLATE_NAME}/shipyard.yaml"
    exit 1
fi

## switch to template directory
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
# Now we iterate through the template folder and add all resources
#
for localFileName in $(tree -i -f)
do 
    # if this is a directory we ignore it
    if [ -d "$localFileName" ]; then continue; fi

    # if this is a service directory and we found the servicedir.txt then we create or onboard the service
    if [[ "${localFileName}" == *"servicedir.txt"* ]]; then 
        # lets check whether its a service_
        if [[ "${localFileName}" == *"/service_"* ]]; then
            RESOURCE_SERVICE_NAME=$(echo "${localFileName##*/service_}")
            SERVICE_NAME=$(echo "${RESOURCE_SERVICE_NAME%%/*}")

            # take into consideration that we may need to create multiple service instances if it contains the XXX placeholder
            instanceCount=1
            if [[ "$SERVICE_NAME" == *"XXX"* ]]; then 
                instanceCount=${INSTANCE_COUNT_XXX}
            fi 

            # now either create a single or multiple instances
            for (( instanceIx=1; instanceIx<=instanceCount; instanceIx++ ))
            do
                INSTANCE_SERVICE_NAME=$(echo "${SERVICE_NAME//XXX/$instanceIx}")

                if [ -d "./service_${SERVICE_NAME}/charts" ]; then 
                    echo "Onboard Keptn Service: ${INSTANCE_SERVICE_NAME} for project ${PROJECT_NAME} with provided helm charts"
                    keptn onboard service $SERVICE_NAME --project="${PROJECT_NAME}" --chart="./service_${SERVICE_NAME}/charts"
                else
                    echo "Create Keptn Service: ${INSTANCE_SERVICE_NAME} for project ${PROJECT_NAME}"
                    keptn create service $SERVICE_NAME --project="${PROJECT_NAME}"
                fi
            done
        fi;

        continue; 
    fi

    # Lets validate that the file is actually a file!
    if ! [ -f "$localFileName" ]; then continue; fi

    # Any other file within a service_SERVICENAME folder will be ignored. if you need to upload files for a service simply put it in the stage_STAGENAME folder
    if [[ "${localFileName}" == *"/service_"* ]]; then continue; fi

    # we are not re-uploading the shipyard.yaml and we ignore the emptydir.txt
    if [[ "${localFileName}" == *"shipyard.yaml"* ]]; then continue; fi

    # Validate if the file is in stage_STAGENAME directory. If so set STAGE_NAME lets remove that directory for the uploaded resourceUri
    RESOURCE_STAGE_NAME=""
    REMOVE_FROM_REMOTE_FILENAME=""
    if [[ "${localFileName}" == *"/stage_"* ]]; then 
      RESOURCE_STAGE_NAME=$(echo "${localFileName##*/stage_}")
      RESOURCE_STAGE_NAME=$(echo "${RESOURCE_STAGE_NAME%%/*}")
      REMOVE_FROM_REMOTE_FILENAME="stage_${RESOURCE_STAGE_NAME}"
      echo $REMOVE_FROM_REMOTE_FILENAME
    fi

    #
    # create a tmp file so we can do any IN-FILE replacements
    cp ${localFileName} ${localFileName}.tmp
    sed -i "s/REPLACE_KEPTN_BRIDGE/${KEPTN_BRIDGE_PROJECT_ESCAPED}/" ${localFileName}.tmp
    sed -i "s/REPLACE_OWNER_EMAIL/${OWNER_EMAIL}/" ${localFileName}.tmp
    sed -i "s/REPLACE_KEPTN_INGRESS/${KEPTN_INGRESS}/" ${localFileName}.tmp
    sed -i "s/REPLACE_KEPTN_PROJECT/${PROJECT_NAME}/" ${localFileName}.tmp
    sed -i "s/REPLACE_SYNTHETIC_LOCATION/${SYNTHETIC_LOCATION}/" ${localFileName}.tmp

    #
    # Create remote file name, e.g: replace any filename placeholders and remove leading ./
    remoteFileName=$(echo "${localFileName/.\//}")
    remoteFileName=$(echo "${remoteFileName/$REMOVE_FROM_REMOTE_FILENAME/}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_PROJECT/$PROJECT_NAME}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_STAGE/$STAGE_NAME}")
    remoteFileName=$(echo "${remoteFileName/KEPTN_SERVICE/$SERVICE_NAME}")

    # echo "Processing localFileName: ${localFileName}"
    # echo "Using remoteFileName: ${remoteFileName}"
    # Lets upload our file

        # take into consideration that we may need to create multiple service instances if it contains the XXX placeholder
    instanceCount=1
    if [[ "$remoteFileName" == *"XXX"* ]]; then 
        instanceCount=${INSTANCE_COUNT_XXX}
    fi 

    # now either create a single or multiple instances
    for (( instanceIx=1; instanceIx<=instanceCount; instanceIx++ ))
    do
        # replace XXX in the remote file name
        remoteFileInstanceName=$(echo "${remoteFileName//XXX/$instanceIx}")

        # replace any occurance in a special tmp.xxx file
        cp ${localFileName}.tmp ${localFileName}.tmp.xxx
        sed -i "s/XXX/${instanceIx}/" ${localFileName}.tmp.xxx

        # adding the file
        keptn add-resource --project="${PROJECT_NAME}" --stage="${RESOURCE_STAGE_NAME}" --resource="${localFileName}.tmp.xxx" --resourceUri="${remoteFileInstanceName}"

        # remove the tmp.xxx file
        rm ${localFileName}.tmp.xxx
    done

    # remove tmp file
    rm ${localFileName}.tmp
done 

# switch back to prev working dir
cd "${currDir}"