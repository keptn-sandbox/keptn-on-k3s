# Dynatrace Cloud Automation Workshop - Instructions for Attendees

This readme contains command line instructions that attendees of the workshop can simply copy & paste when the instructor walks through the specific section in the workshop

## Access to the lab environment

### Login Credentials

Your instructor will give you login credentials to
* A Dynatrace Environment
* A Cloud Automation Environment
* A Bastion Host

### Install Keptn CLI locally

While the Bastion host can be ued to trigger keptn CLI commands you can also install the Keptn CLI yourself.
Please ask your instructor which version to install so it matches the cloud automation instance. Or simple download it via the download link in the Cloud Automation UI (top right menu)
Here the sample on how to install e.g: 0.9.2 CLI on your Linux:
```sh
curl -sL https://get.keptn.sh | KEPTN_VERSION=0.9.2 sudo -E bash
```

To connect to local Keptn CLI with your Cloud Automation instance copy the `keptn auth` command from the Cloud Automation UI (top right)

To validate you are connected you can run 
```
keptn status
``` 

## Our sample app today

The workshop will use a very simple Node.js based sample application. Details can be found here https://github.com/grabnerandi/simplenodeservice.

### Your instance of the app

Every attendee has their own pipeline to deploy the sample app across staging and production. To differentiate our instances every attendee picked a `TenantID` from the Excel list, e.g: aapl, goog, sbux, ...
If your assigned TenantID is aapl then the service instance name is `tnt-aapl-svc`

### 4 different versions of the app available
The sample application used comes with 4 different container versions that are all uploaded to dockerhub:

| Image | Description |
| ------ | ------------- |
| grabnerandi/simplenodeservice:1.0.1 | Version 1, green background, no problems |
| grabnerandi/simplenodeservice:2.0.1 | Version 2, yellow background, high failure rate |
| grabnerandi/simplenodeservice:3.0.1 | Version 3, no problems |
| grabnerandi/simplenodeservice:4.0.1 | Version 4, only problems in production |

## Trigger a new version deployment of your service

During the workshop you will be able to trigger a new deployment of your service, e.g: `tnt-aapl-svc`. All you need is to trigger a delivery sequence for our `delivery-demo`project, specify your assigned service and select the stage you want to start delivery in: `staging` or `production`

### End-2-End Delivery: Staging & Production

To trigger a full end-2-end delivery (staging and production) in the `delivery-demo` project you can execute the following command where 
* xxxx needs to be replaced with your demo service tenant, e.g: aapl, goog, ...
* you can choose which image version to deploy
```sh
keptn trigger delivery --project=delivery-demo --stage=staging --service=tnt-xxxx-svc --image=grabnerandi/simplenodeservice:1.0.1
```

### Delivery directly into production

For some of our exercises we may shortcut the deployment and deploy straight into `production`. For this we simply change the stage name parameter to production shown like here:
```sh
keptn trigger delivery --project=delivery-demo --stage=production --service=tnt-xxxx-svc --image=grabnerandi/simplenodeservice:1.0.1
```

## Triggering SLO based quality gates

One of the exercises focuses on SLO evaluations (aka quality gates). To trigger an SLO based evaluation we will use both the Keptn CLI as well as the Keptn API to trigger an evaluation for your service, e.g: `tnt-aapl-svc` in the `dynatrace` project for the stage `quality-gate`. 

### Trigger evaluation through the Keptn CLI

The Keptn CLI allows us to trigger the evaluation by giving a timeframe and optionally labels that will show up as metadata. In the following example replace xxxx with your `TenantID`:

```sh
keptn trigger evaluation --project=dynatrace --stage=quality-gate --service=tnt-xxxx-svc --timeframe=30m --labels=buildId=1,executedBy=manual
```

The label `buildId` will be treated as the name of that evaluation. In our exercises we will run multiple evaluations simulating different builds. Therefore make sure to change buildId accordingly.

### Trigger evaluation through the Keptn API

The Keptn API can be triggered like any API, e.g: via curl, wget or your favorite REST Client. One option we have is to use the Swagger Web UI where we can also trigger an API in a convenient way:

To help you here is the data to put into the different fields of the evaluation API endpoint:
| Field | Value |
| ---- | ----|
| project|  `dynatrace` |
| stage | `quality-gate` |
| service | `tnt-xxxx-svc` |
| evaluation |  
```{
  "labels": {
    "executedBy": "api",
    "buildId": "3"
  },
  "timeframe": "30m"
}
```

