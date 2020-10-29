#!/bin/bash

if [[ -z "$DT_TENANT" || -z "$DT_API_TOKEN" || -z "$KEPTN_ENDPOINT" || -z "$KEPTN_API_TOKEN" ]]; then
  echo "DT_TENANT, DT_API_TOKEN, KEPTN_ENDPOINT & KEPTN_API_TOKEN MUST BE SET!!"
  exit 1
fi

KEPTN_PROJECT=$1
if [[ -z "$KEPTN_PROJECT" ]]; then
  KEPTN_PROJECT="demo-remediation"
fi 

KEPTN_STAGE=$2
if [[ -z "$KEPTN_STAGE" ]]; then
  KEPTN_STAGE="production"
fi 

KEPTN_SERVICE=$3
if [[ -z "$KEPTN_SERVICE" ]]; then
  KEPTN_SERVICE="allproblems"
fi 

echo "Will create a Problem Notification in Dynatrace to send all problems to Keptns $KEPTN_PROJECT.$KEPTN_STAGE.$KEPTN_SERVICE"

KEPTNPAYLOAD='{
    \"specversion\":\"0.2\",
    \"type\":\"sh.keptn.events.problem\",
    \"source\":\"dynatrace\",
    \"id\":\"{PID}\",
    \"time\":\"\",
    \"contenttype\":\"application/json\",
    \"data\": {
        \"State\":\"{State}\",
        \"ProblemID\":\"{ProblemID}\",
        \"PID\":\"{PID}\",
        \"ProblemTitle\":\"{ProblemTitle}\",
        \"ProblemURL\":\"{ProblemURL}\",
        \"ProblemDetails\":{ProblemDetailsJSON},
        \"Tags\":\"keptn_project:'$KEPTN_PROJECT',keptn_stage:'$KEPTN_STAGE',keptn_service:'$KEPTN_SERVICE',{Tags}\",
        \"ImpactedEntities\":{ImpactedEntities},
        \"ImpactedEntity\":\"{ImpactedEntity}\"
    }
}'

PAYLOAD='
{
  "name": "Keptn Remediation Demo for '$KEPTN_PROJECT.$KEPTN_STAGE.$KEPTN_SERVICE'",
  "alertingProfile" : "Default",
  "active" : "true",
  "type": "WEBHOOK",
  "url" : "'$KEPTN_ENDPOINT'/api/v1/event",
  "acceptAnyCertificate": true,
  "payload" : "'$KEPTNPAYLOAD'",
  "headers : [
    { "name" : "x-token", "value" : "'$KEPTN_API_TOKEN'"},
    { "name" : "Content-Type", "value" : "application/cloudevents+json"}
  ]
}
'
curl -X POST \
          "https://$DT_TENANT/api/config/v1/notifications" \
          -H 'accept: application/json; charset=utf-8' \
          -H "Authorization: Api-Token $DT_API_TOKEN" \
          -H 'Content-Type: application/json; charset=utf-8' \
          -d "$PAYLOAD" \
          -o curloutput.txt
cat curloutput.txt