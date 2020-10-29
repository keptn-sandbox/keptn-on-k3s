#!/bin/bash

if [[ -z "$DT_TENANT" || -z "$DT_API_TOKEN" || -z "$DT_ENTITY_ID" ]]; then
  echo "DT_TENANT, DT_API_TOKEN & DT_ENTITY_ID MUST BE SET!!"
  echo "DT_ENTITY_ID is the Dynatrace Monitored Entity ID, e.g: HOST-ABCD123213123 that this script sends an error event to"
  exit 1
fi

PROBLEM_TITLE=$1
if [[ -z "$PROBLEM_TITLE" ]]; then
  PROBLEM_TITLE="Simulated Power outage"
fi 

EVENT_TYPE=$2
if [[ -z "$EVENT_TYPE" ]]; then
  EVENT_TYPE="ERROR_EVENT"
fi 

echo "Sending a custom '$EVENT_TYPE' event to Dynatrace ($DT_TENANT) for entity ($DT_ENTITY_ID). Problem '$PROBLEM_TITLE' will help you test the auto-remediation workflows with Keptn & Dynatrace"
echo "To parameterize EVENT_TYPE $ PROBLEM_TITLE simply pass them as parameters to the script. Here is an example:"
echo "createproblem.sh PERFORMANCE_EVENT 'Critical Performance Issue'"

PAYLOAD='
{
  "title": "'$PROBLEM_TITLE'",
  "source" : "Keptn Demo Script",
  "description" : "There was a problem detected which should now trigger the Keptn Remediation Workflow",
  "eventType": "'$EVENT_TYPE'",
   "attachRules":{
      "entityIds" : ["'$DT_ENTITY_ID'"]
  },
  "customProperties":{
    "Triggered by": "Keptn Demo Script"
  }
}
'
curl -X POST \
          "https://$DT_TENANT/api/v1/events" \
          -H 'accept: application/json; charset=utf-8' \
          -H "Authorization: Api-Token $DT_API_TOKEN" \
          -H 'Content-Type: application/json; charset=utf-8' \
          -d "$PAYLOAD" \
          -o curloutput.txt
cat curloutput.txt