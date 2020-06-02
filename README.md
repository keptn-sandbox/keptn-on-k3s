# keptn-on-k3s

Installs k3s and keptn quality gates

## Prerequisites:
  * A machine which is able to execute bash scripts
  
## Currently tested on:
  * CentOS 8
  
* Works on a machine with 1 (v)CPU and 4GB of memory

## Usage (Autodetect IP, need hostname -I):
```./install-keptn-on-k3s.sh``` 

## Usage (GKE):
```./install-keptn-on-k3s.sh gke``` 

## Usage (Custom IP):
```./install-keptn-on-k3s.sh <IP>```
