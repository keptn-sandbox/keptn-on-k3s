# Keptn on k3s with demo projects for Dynatrace

## Cloud Automation Workshop

If you navigate to this repository because you are part of a **Cloud Automation Workshop** then check out the following resources
* [Cloud Automation Hands-On Instructions](./cloudautomation/INSTRUCTIONS.md)
* [Cloud Automation Workshop Setup Instructions](./cloudautomation/README.md)

## Running on Keptn on k3s with demo projects

**Before you start - make sure to pick the right branch for your Keptn Version!**

| Authors | Tutorial Version | Keptn Version | Comment |
| ------ | ------------- | --------------| -------- |
| [@thschue](https://github.com/thschue) | [release-0.6.2](https://github.com/keptn-sandbox/keptn-on-k3s/tree/release-0.6.2) | 0.6.2 | Initial Release |
| [@grabnerandi](https://github.com/grabnerandi) | [release-0.7.3](https://github.com/keptn-sandbox/keptn-on-k3s/tree/release-0.7.3) | 0.7.3 | Adding Dynatrace Use Cases |
| [@grabnerandi](https://github.com/grabnerandi) | [release-0.8.0](https://github.com/keptn-sandbox/keptn-on-k3s/tree/release-0.8.0) | 0.8.0 | Updates to Keptn 0.8 |
| [@grabnerandi](https://github.com/grabnerandi) | [release-0.9.0](https://github.com/keptn-sandbox/keptn-on-k3s/tree/release-0.9.0) | 0.9.1 | Updates to Keptn 0.9.x |

This repo automates the installation of [Keptn's](https://keptn.sh) Control Plane, Delivery or Execution. For that it will automatically install a [k3s](https://k3s.io). 
This is your fastest way to explore the following use cases:
* SLI/SLO-based Quality Gates
* Performance as a Self-Service
* Multi-Stage Delivery
* Automated Operation (aka Auto-Remediation).

Depending on which options you choose the script will install
* JMeter Service as a testing service
* Istio as Service Mesh for Blue/Green
* Argo Rollouts for Canary Deployments
* Generic Executor to execute remediation scripts
* Monaco Service to automate Dynatrace Monitoring Configuration

This tutorial was heavily driven to use cases that integrate with Dynatrace which is why Dynatrace is prominently featured as a monitoring solution. You can however also run the script using Prometheus to provide SLIs for your quality gates!

After the installation is complete you are free to install any additional Keptn Services such as Notification, Jenkins, Grafana, Jira ... service. Find those services in the [Keptn-Contrib](https://github.com/keptn-contrib) organization or [Keptn-Sandbox](https://github.com/keptn-sandbox)

## Use cases, pre-requisites and supported stacks

* If you want to watch our Keptn on k3s webinar [click here!](https://www.youtube.com/watch?v=hx0NHj4u7ic)

* If you want to use **Keptn with Dynatrace** check out [Keptn for Dynatrace in 5 Minutes](README-KeptnForDynatrace.md) or watch the specific tutorials
  * [Keptn Quality Gates for Dynatrace in 5 minutes](https://www.youtube.com/watch?v=650Gn--XEQE)
  * [Automated Performance with Keptn, JMeter and Dynatrace in 5 minutes](https://www.youtube.com/watch?v=m4dkR8QxYSE)
  * [Keptn Auto Remediation for Dynatrace in 5 minutes](https://www.youtube.com/watch?v=05Mzs-Donr0)

### Use Case
 * You want to try out Keptn
 * You don't want to deal with installing Kubernetes
 * You have access to a Linux host
 
### But:
 * You don't want to use this in production (currently)
 * You don't plan to upgrade this installation (currently, but maybe reinstall) 

### Prerequisites:
  * A machine which is able to execute bash scripts and that allows incoming HTTP (80) & HTTPS (443) traffic. I have tested all this on EC2 AWS Linux machines

### Required tools
To install you need the following tools on your machine: git, curl, tree, jq, tree, yq! Here instructions on how to download on an EC2 Linux
```console
sudo yum update -y
sudo yum install git -y
sudo yum install curl -y
sudo yum install jq -y
sudo yum install tree -y
sudo wget https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

git clone https://github.com/keptn-sandbox/keptn-on-k3s
cd keptn-on-k3s
git checkout release-0.9.0
```

### Currently tested on:
  * Amazon Linux 2

**ATTENTION**: if you try this on an EC2, GCP, ... instance please make sure to allow inbound traffic for HTTP & HTTPS!

* Basic install (for quality gates only) works on a machine with 2 (v)CPU and 8GB of memory, e.g: t3.large
* Advanced install (with delivery & testing) needs a machine with at least 8 (v)CPU and 32GB of memory, e.g: t3.2xlarge

### Parameters
The script allows a couple of parameters
| Parameter Name | Values | Comment |
| ------------------------------ | ------ | --------|
| `--type` | all (default), k3s, keptn, demo, gitus | Will either install everything (all), just k3s, just keptn (assuming that kubectl is pointing to a k8s cluster), demo (just the demo components), gitus (will create Git Upstreams for each Keptn Project) |
| `--controlplane` | | This is default, it will just install Keptn Control Plane on this k3s allowing Quality Gates & Auto-Remediation |
| `--deliveryplane` | | This option will install Keptn Delivery Plane - that is Control Plane + Helm (for Deployment) + JMeter (for Testing). This will also install Istio |
| `--executionplane` | | This option only installs Keptn's Execution Plane + Helm (for Deployment) + JMeter (for Testing) + Istio. This also requires you to set some Env-Variables pointing to the Keptn Control Plane |
| `--with-prometheus` | | Will enable Prometheus Support and install Prometheus in the `prometheus` namespace. |
| `--with-dynatrace` | | Will enable Dynatrace Support.<br>Requires DT_API_TOKEN and DT_TENANT env variables to be set |
| `--with-jmeter` | | Will make sure to install JMeter Service in case not already selected by another option, e.g: deliveryplane or execution plane |
| `--with-slackbot` | | Will install the Keptn slackbot. <br> Requires SLACKBOT_TOKEN env variable to be set |
| `--use-xip` | | Will use a xip.io domain, e.g: your.ip.xip.io |
| `--use-nip` | | Will use a nip.io domain which is sometimes more reliable than using xip.io. Will also be used when LE_STAGE=staging and no FQDN is specified |
| `--provider` | aws<br>gcp<br>digitalocean<br>EMPTY | handles IP gathering based on provider or uses hostname in case its empty |
| `--ip` | "YOURIP" | Allows you to pass your own IP of your host, use double quotation marks |
| `--letsencrypt` | | Will create a Letsencrypt certificate |
| `--fqdn` | YOURFQDN | Allows you to pass your own hostname, allows you to create production LetsEncrypt Certificates, You need to create your own DNS entry |
| `--with-demo` | dynatrace prometheus | Will install demo projects for Dynatrace or Prometheus |
| `--with-gitea` |  | Will install Gitea and upstream Git repos for every Keptn project  |
| `--disable-bridge-auth` |  | Will disable the password check when accessing Keptn Bridge (not recommended for anything else than demo purposes)  |

### TLS Certificates
keptn-on-k3s comes with [cert-manager](https://cert-manager.io/). By default, a self-signed certificate is generated. By adding `--letsencrypt` as a parameter, and a CERT_EMAIL is exported, you will create a LetsEncrypt-Staging certificate. By additionally exporting `LE_STAGE=production`, a LetsEncypt Production certificate will be issued (will not work with xip.io and nip.io). 

## Installing Keptn for Dynatrace in 5 Minutes

For all details please check out [Keptn for Dynatrace in 5 Minutes](README-KeptnForDynatrace.md)

Here are three common installation scenarios:

### Keptn with Dynatrace for all Use Cases and Samples

The installation scripts for Dynatrace needs a couple of env-variables:

```console
$ export DT_TENANT=abc12345.live.dynatrace.com        # Host name of your Dynatrace Tenant
$ export DT_API_TOKEN=YOURTOKEN                       # Dynatrace API token to let Keptn pull SLIs from Dynatrace
$ export DT_PAAS_TOKEN=YOURPAASTOKEN                  # Dynatrace PAAS token as script will install OneAgent
$ export OWNER_EMAIL=yourdynatraceuser@yourmail.com   # Your username in Dynatrace
$ export LE_STAGE=staging                             # This is needed for certificate creation
```

When you have an EC2 machine you can run the following script which will install Keptn using the EC2 machines public IP to expose the keptn services via e.g: http://keptn.YOUR.IP.nip.io

```console
./install-keptn-on-k3s.sh --deliveryplane --provider aws --with-dynatrace --with-demo dynatrace --letsencrypt --with-gitea
```

If you create your own DNS Entry for your IP, e.g: Using Route53 to map to your public IP of your EC2 instance then you can run this
```console
./install-keptn-on-k3s.sh --deliveryplane --provider aws --with-dynatrace --with-demo dynatrace --letsencrypt --with-gitea --fqdn yourkeptndomain.abc
```

If you just want quality gates then do this
```console
./install-keptn-on-k3s.sh --controlplane --provider aws --with-dynatrace --with-demo dynatrace --letsencrypt --with-gitea
```

## Other installation examples

Here are a couple of installation examples

### Installing on any Linux with Prometheus Support:

This option will auto-detect your IP address by using *hostname -I* 
```console
# For the brave, with Prometheus-Service and SLI Provider
./install-keptn-on-k3s.sh --with-prometheus
```

### Installing on GCP:

This option passes the *--provider gcp** option. In this case the script queries the external IP address of your GCP instance.
```console
./install-keptn-on-k3s.sh --provider gcp
``` 

### Installation using a custom IP:

This option allows you to specify which IP address to be used to expose Keptn services (API, Bridge ...) on this machine!

```console
./install-keptn-on-k3s.sh --ip <IP>
```

### Cleanup: Uninstall k3s
```console
k3s-uninstall.sh
```

Also make sure to remove any other potentially created files as part of the demo installations!
