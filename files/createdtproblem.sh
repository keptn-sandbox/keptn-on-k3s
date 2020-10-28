#!/bin/bash

if [[ -z "$DT_TENANT" || -z "$DT_API_TOKEN" || -z "$DT_ENTITY_ID" ]]; then
  echo "DT_TENANT, DT_API_TOKEN & DT_ENTITY_ID MUST BE SET!!"
  exit 1
fi

echo "This will open a custom problem in Dynatrace ($DT_TENANT) for entity ($DT_ENTITY_ID) to help you test the auto-remediation workflows with Keptn & Dynatrace"

PAYLOAD='
{
  "title": "Simulated Power outage - 2",
  "source" : "Keptn Demo Script",
  "description" : "A power outage was detected affecting hosts in room123",
  "eventType": "ERROR_EVENT",
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