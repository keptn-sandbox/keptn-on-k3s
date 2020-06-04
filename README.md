# keptn-on-k3s

Installs k3s and keptn quality gates

## Prerequisites:
  * A machine which is able to execute bash scripts
  * curl
  
## Currently tested on:
  * CentOS 8
  * ArchLinux
  * Debian on GCP
  
* Works on a machine with 1 (v)CPU and 4GB of memory

## Usage (Autodetect IP, need hostname -I):
```
# For the brave, with Prometheus-Service and SLI Provider
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/master/install-keptn-on-k3s.sh | bash -s - --with-prometheus
```
```./install-keptn-on-k3s.sh``` 

## Usage (GCP Instance):
```
curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/master/install-keptn-on-k3s.sh | bash -s - --provider gcp
``` 

## Usage (Custom IP):
```curl -Lsf https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/master/install-keptn-on-k3s.sh | bash -s - --ip <IP>```
