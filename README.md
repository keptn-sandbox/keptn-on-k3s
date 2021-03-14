# Keptn on k3s (with sample projects)

Before you start - make sure to pick the right branch for your Keptn Version!

| Authors | Tutorial Version | Keptn Version | Comment |
| ------ | ------------- | --------------| -------- |
| [@thschue](https://github.com/thschue) | [release-0.6.2](https://github.com/keptn-sandbox/keptn-on-k3s/tree/release-0.6.2) | 0.6.2 | Initial Release |
| [@grabnerandi](https://github.com/grabnerandi) | [release-0.7.3](https://github.com/keptn-sandbox/keptn-on-k3s/tree/release-0.7.3) | 0.7.3 | Adding Dynatrace Use Cases |
| [@grabnerandi](https://github.com/grabnerandi) | [release-0.8.0](https://github.com/keptn-sandbox/keptn-on-k3s/tree/release-0.8.0) | 0.8.0 | Updates to Keptn 0.8 |

Installs [Keptn's](https://keptn.sh) Control Plane on [k3s](https://k3s.io) which is your fastest and easiest way to leverage Keptn for SLI/SLO-based Quality Gates, Performance as a Self-Service and Automated Operation (aka Auto-Remedition).

Keptn Control Plane includes Keptns Bridge, API and the Quality Gate capability and optionally the JMeter service! But does _not_ include capabilities for using Keptn as deployment tool.

The install scripts provides with the additional options to configure either Prometheus or Dynatrace support automatically as well as installing the JMeter service to enable the Performance as a Self-Service capability!

On top of that you are free to install any other Keptn Service such as the Notification, Jenkins, Grafana, Jira ... service. Find those services in the [Keptn-Contrib](https://github.com/keptn-contrib) organization.

## Use cases, pre-requisites and supported stacks

* If you want to watch our Keptn on k3s webinar [click here!](https://www.youtube.com/watch?v=hx0NHj4u7ic)

* If you want to use **Keptn with Dynatrace** check out [Keptn for Dynatrace in 5 Minutes](README-KeptnForDynatrace.md) or the specific tutorials
  * [Keptn Quality Gates for Dynatrace in 5 minutes](https://www.youtube.com/watch?v=650Gn--XEQE)
  * [Keptn Auto Remediation for Dynatrace in 5 minutes](https://www.youtube.com/watch?v=05Mzs-Donr0)

### Use Case
 * You want to try out Keptn
 * You don't want to deal with Kubernetes
 * You have access to a Linux host
 
### But:
 * You don't want to use this in production (currently)
 * You don't plan to upgrade this installation (currently, but maybe reinstall) 

### Prerequisites:
  * A machine which is able to execute bash scripts and that allows incoming HTTP (80) & HTTPS (443) traffic
  * curl

### Required tools
To install you need the following tools on your machine: git, curl, tree, jq, yq! Here instructions on how to download on an EC2 Linux
```sh
sudo yum update -y
sudo yum install git -y
sudo yum install curl -y
sudo yum install jq -y
sudo yum install tree -y
sudo wget https://github.com/mikefarah/yq/releases/download/v4.2.0/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

git clone https://github.com/keptn-sandbox/keptn-on-k3s
cd keptn-on-k3s
git checkout release-0.8.0
```

### Currently tested on:
  * CentOS 8
  * ArchLinux
  * Debian on GCP
  * Amazon Linux 2

**ATTENTION**: if you try this on an EC2, GCP, ... instance please make sure to allow inbound traffic for HTTP & HTTPS!

* Basic install (for quality gates only) works on a machine with 1 (v)CPU and 4GB of memory
* Advanced install (with delivery & testing) needs a machine with at least 4 (v)CPU and 16GB of memory

### Parameters
The script allows a couple of parameters
| Parameter Name | Values | Comment |
| ------------------------------ | ------ | --------|
| `--type` | all (default), k3s, keptn, demo, gitus | Will either install everything (all), just k3s, just keptn (assuming that kubectl is pointing to a k8s cluster), demo (just the demo components), gitus (will create Git Upstreams for each Keptn Project) |
| `--controlplane` | | This is default anyway - but - it would jus install Keptn Control Plane on this k3s |
| `--deliveryplane` | | This option will install Keptn Delivery Plane - that is Control Plane + Helm + JMeter |
| `--executionplane` | | This option only installs Keptn's Execution Plane but also requires you to set  |
| `--with-prometheus` | | Will enable Prometheus Support |
| `--with-dynatrace` | | Will enable Dynatrace Support.<br>Requires DT_API_TOKEN and DT_TENANT env variables to be set |
| `--with-jmeter` | | Will install JMeter Service |
| `--with-slackbot` | | Will install the Keptn slackbot. <br> Requires SLACKBOT_TOKEN env variable to be set |
| `--use-xip` | | Will use a xip.io domain, will also be added when LE_STAGE=staging is selected |
| `--provider` | aws<br>gcp<br>digitalocean<br>EMPTY | handles IP gathering based on provider or uses hostname in case its empty |
| `--ip` | YOURIP | Allows you to pass your own IP of your host |
| `--fqdn` | YOURFQDN | Allows you to pass your own hostname, allows you to create production LetsEncrypt Certificates, You need to create your own DNS entry |
| `--with-demo` | dynatrace | Will install demo projects for Dynatrace |
| `--with-gitea` |  | Will install Gitea and upstream Git repos for every Keptn project  |

### TLS Certificates
keptn-on-k3s comes with [cert-manager](https://cert-manager.io/). By default, a self-signed certificate is generated. By adding `--letsencrypt` as a parameter, and a CERT_EMAIL is exported, you will create a LetsEncrypt-Staging certificate. By additionally exporting `LE_STAGE=production`, a LetsEncypt Production certificate will be issued (will not work with xip.io and nip.io). 

## Installing Keptn for Dynatrace in 5 Minutes

For all details please check out [Keptn for Dynatrace in 5 Minutes](README-KeptnForDynatrace.md)

As an example - here is your script to install Keptn for Dynatrace on an Amazon Linux 2 EC2 machine with pre-configured projects for Quality Gates, Performance Automation & Auto-Remediation:
```console
./install-keptn-on-k3s.sh --provider aws --with-dynatrace --with-demo dynatrace --letsencrypt --with-gitea
```

If you have your own DNS name for your machine, e.g: creating a Route53 entry to your public IP of your EC2 instance you can run this command
```console
./install-keptn-on-k3s.sh --provider aws --with-dynatrace --with-demo dynatrace --letsencrypt --with-gitea --fqdn yourkeptndomain.abc
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
