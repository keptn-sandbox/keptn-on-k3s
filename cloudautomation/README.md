# Dynatrace Cloud Automation Workshop

This folder contains scripts to setup a Dynatrace Cloud Automation Workshop

It's assumed you have the following:
1. A Dynatrace Environment (SaaS or Managed with exposed API)
2. A Cloud Automation SaaS Environment (aka Keptn SaaS Control Plane)
3. An EC2 Amazon Linux instance (min: m5.8xlarge)

What you need is:
1. **DT_TENANT**: hostname of your SaaS or managed environment, e.g: abc12345.live.dynatrace.com
2. **DT_API_TOKEN**: It needs configuration read/write access. Best is to give it all privileges that don't touch sensitive data
3. **DT_PAAS_TOKEN**: A PAAS Token as the script also installs a OneAgent & ActiveGate on your Bastion Host
4. **KEPTN_CONTROL_PLANE_DOMAIN**: hostname of your Cloud Automation enviornment, e.g: abc12345.cloudautomation.live.dynatrace.com
5. **KEPTN_CONTROL_PLANE_API_TOKEN**: API Token for your Cloud Automation environment
6. **OWNER_EMAIL**: The username (=email) of your Dynatrace user. It will be used to create dashboards in your tenant

## Installing the workshop

### Step 1: Export Environment Variables

Logon to your EC2 Amazon Linux instance and execute the following:

```bash
export DT_TENANT=abc12345.live.dynatrace.com
export DT_API_TOKEN=dt0c01.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
export DT_PAAS_TOKEN=dt0c01.YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY

export KEPTN_CONTROL_PLANE_DOMAIN=abc12345.cloudautomation.live.dynatrace.com
export KEPTN_CONTROL_PLANE_API_TOKEN=ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ

export KEPTN_EXECUTION_PLANE_STAGE_FILTER=
export KEPTN_EXECUTION_PLANE_SERVICE_FILTER=
export KEPTN_EXECUTION_PLANE_PROJECT_FILTER=

export OWNER_EMAIL=youremail@domain.com
```

### Step 2: Clone the git repo

Now its time to clone this git repo
```bash
git clone https://github.com/keptn-sandbox/keptn-on-k3s
```

### Step 3: Install k3s

Now its time to run the installation script!
```bash
./install-keptn-on-k3s.sh --executionplane --provider aws --with-jmeter --with-genericexec --with-monaco --with-gitea --use-nip
```

### Step 4: Install demo projects

Final step is to install the demo projects used in the workshop
```bash
cd cloudautomation
./install-cloudautomation-workshop.sh 
```