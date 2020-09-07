# Keptn Control Plane on k3s

Installs [k3s](https://k3s.io) and [Keptn's](https://keptn.sh) Control Plane. 
Keptn Control Plane includes Keptns Bridge, API and the Quality Gate capability and optionally the JMeter service! But does _not_ include capabilities for using Keptn as deployment tool.

The install scripts provides with the additional options to configure either Prometheus or Dynatrace support automatically as well as installing the JMeter service to enable the Performance as a Self-Service capability!

On top of that you are free to install any other Keptn Service such as the Notification, Jenkins, Grafana, Jira ... service. Find those services in the [Keptn-Contrib](https://github.com/keptn-contrib) organization.

If you want to watch our Keptn on k3s webinar [click here!](https://www.youtube.com/watch?v=hx0NHj4u7ic)

## Use Case
 * You want to try out keptn
 * You don't want to deal with Kubernetes
 * You have access to a Linux host
 
## But:
 * You don't want to use this in production (currently)
 * You don't plan to upgrade this installation (currently, but maybe reinstall) 

## Prerequisites:
  * A machine which is able to execute bash scripts
  * curl
  
## Currently tested on:
  * CentOS 8
  * ArchLinux
  * Debian on GCP
  * Amazon Linux
  
* Works on a machine with 1 (v)CPU and 4GB of memory

## Parameters
The script allows a couple of parameters
| Parameter Name | Value | Comment |
| ------------- | ------ | --------|
| --with-prometheus | | Will enable Prometheus Support |
| --with-dynatrace | | Will enable Dynatrace Support. Requires DT_API_TOKEN, DT_PAAS_TOKEN and DT_TENANT env variables to be set |
| --with-jmeter | | Will install JMeter Extended Service |
| --with-slackbot | | Will install the Keptn slackbot. Requires SLACKBOT_TOKEN env variable to be set |
| --use-xip | | Will use a xip.io domain, will also be added when LE_STAGE=staging is selected |
| --provider | aws,gcp,digitalocean,EMPTY | handles IP gathering based on provider or uses hostname in case its empty |
| --ip | YOURIP | Allows you to pass your own IP of your host |
| --fqdn | YOURFQDN | Allows you to pass your own hostname, allows you to create production LetsEncrypt Certificates, You need to create your own DNS entry

## TLS Certificates
keptn-on-k3s comes with [cert-manager](https://cert-manager.io/). By default, a self-signed certificate is generated. By adding `--letsencrypt` as a parameter, and a CERT_EMAIL is exported, you will create a LetsEncrypt-Staging certificate. By additionally exporting `LE_STAGE=production`, a LetsEncypt Production certificate will be issued (will not work with xip.io and nip.io). 
  
## Usage (Autodetect IP, need hostname -I):
```
# For the brave, with Prometheus-Service and SLI Provider
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/0.7.1/install-keptn-on-k3s.sh | bash -s - --with-prometheus
```

## Usage (GCP Instance):
```
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/0.7.1/install-keptn-on-k3s.sh | bash -s - --provider gcp
``` 

## Usage (EC2 Instance with Dynatrace & JMeter):

FYI: For enabling Dynatrace support you must first export DT_TENANT & DT_API_TOKEN so that Keptn can connect to your Dynatrace Tenant!

```
export DT_TENANT=abc12345.live.dynatrace.com
export DT_API_TOKEN=YOURTOKEN
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/0.7.1/install-keptn-on-k3s.sh | bash -s - --provider aws --with-dynatrace --with-jmeter
``` 

## Usage (Custom IP):
```curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/0.7.1/install-keptn-on-k3s.sh | bash -s - --ip <IP>```

## Cleanup
``` k3s-uninstall.sh ```
