# Delivery Rollout Example

This example uses Argo Rollouts for canary deployments of the simplenode node.js based microservice

To onboard this project to your Keptn you can call

 ```console
 ./create-keptn-project-from-template.sh delivery-rollout andreas.grabner@dynatrace.com delivery-rollout
 ```

 To trigger a new deployment you can send an event via the Keptn Swagger UI or via Keptn send event using the content of prod.deployment.triggered.json

 ```console
 keptn send event -f prod.deployment.triggered.json
 ```