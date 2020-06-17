# keptn-on-k3s

Installs k3s and keptn quality gates

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
| --with-dynatrace | | Will enable Dynatrace Support. Requires DT_API_TOKEN and DT_TENANT env variables to be set
| --with-jmeter | | Will install JMeter Extended Service |
| --provider | aws,gcp,digitalocean,<empty> | handles IP gathering based on provider |
| --IP | <YOURIP> | Allows you to pass your own IP of your host |

## Usage (Autodetect IP, need hostname -I):
```
# For the brave, with Prometheus-Service and SLI Provider
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/master/install-keptn-on-k3s.sh | bash -s - --with-prometheus
```

## Usage (GCP Instance):
```
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/master/install-keptn-on-k3s.sh | bash -s - --provider gcp
``` 

## Usage (EC2 Instance with Dynatrace & JMeter :
```
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/master/install-keptn-on-k3s.sh | bash -s - --provider aws --with-dynatrace --with-jmeter
``` 

## Usage (Custom IP):
```curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/master/install-keptn-on-k3s.sh | bash -s - --ip <IP>```

## Cleanup
``` k3s-uninstall.sh ```
