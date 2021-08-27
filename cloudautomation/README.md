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

export OWNER_EMAIL=youremail@domain.com

export ISTIO=false
```

### Step 2: Clone the git repo

Now its time to clone this git repo
```bash
git clone https://github.com/keptn-sandbox/keptn-on-k3s
cd keptn-on-k3s
git checkout release-0.8.0
```

### Step 3a: Install a single k3s Execution Plane for Production & Staging

**This installation option is good if you don't have too many tenants in your workshop and if your k3s host has sufficient CPU and Memory**

Now its time to run the installation script!
```bash
export KEPTN_EXECUTION_PLANE_STAGE_FILTER=
export KEPTN_EXECUTION_PLANE_SERVICE_FILTER=
export KEPTN_EXECUTION_PLANE_PROJECT_FILTER=
./install-keptn-on-k3s.sh --executionplane --provider aws --with-genericexec --with-monaco --with-gitea --use-nip
```

### Step 3b: Install a two k3s Execution Planes. One for Production & one for Staging

**This requires two smaller hosts as each host is only handling either production or staging traffic**

We first install the Execution Plane targeted for Production (here we also install Gitea)
```bash
export KEPTN_EXECUTION_PLANE_STAGE_FILTER=production
export KEPTN_EXECUTION_PLANE_SERVICE_FILTER=
export KEPTN_EXECUTION_PLANE_PROJECT_FILTER=
./install-keptn-on-k3s.sh --executionplane --provider aws --with-genericexec --with-monaco --with-gitea --use-nip
```

And now the Execution Plane targeted for Staging (no need for gitea)
```bash
export KEPTN_EXECUTION_PLANE_STAGE_FILTER=staging
export KEPTN_EXECUTION_PLANE_SERVICE_FILTER=
export KEPTN_EXECUTION_PLANE_PROJECT_FILTER=
./install-keptn-on-k3s.sh --executionplane --provider aws --with-genericexec --with-monaco --use-nip
```


### Step 4: Install demo projects

The demo project is called `demo-delivery`. It is a two stage delivery pipeline of services with the name pattern tnt-TENANTID-svc.
The idea is that every attendee of the workshop gets its own service. The story is that we are all working for a SaaS provider and we are all responsible for our individual tenants.

In order to create tenants for each student we need to create a file called `tenants.sh` in the `cloudautomation/scripts` folder that sets the TENANTID into an array as described here. The tenant IDs must only contain alphanumeric characters and have to be lowercase. Here is an example for 3 tenants:

**./cloudautomation/scripts/tenants.sh:**
```sh
INSTANCE_ARRAY=(angr here saif)
```

**TIP for Workshops:** To come up with the list of tenants a suggestion is to use the first two characters of your attendees first and last names for the tenant IDs, e.g: Andreas Grabner would be angr, Henrik Rexed would be here, ... 
Another option would be to use e.g: stock symbols. With this you can assign everyone a stock symbol that is easy to remember, e.g: aapl, tsla, ... There is a sample file called `tenants.stocksample.sh`. It contains 30 symbol names (some made up) :-)

**IMPORTANT:** Dynatrace automatically detects "version information" in pod names by removing hexadecimal patterns. So - make sure that these tenantIDs do not include numbers or just letters from A to F


Now we are ready and can create the demo project for that workshop
```bash
cd cloudautomation
export OWNER_EMAIL=youremail@domain.com

export KEPTN_CONTROL_PLANE_DOMAIN=abc12345.cloudautomation.live.dynatrace.com
export KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN=your.productionk3s.i.p.nip.io   (this is the production execution plane IP)
export KEPTN_PRODUCTION_INGRESS=your.productionk3s.i.p.nip.io
export KEPTN_STAGING_INGRESS=your.stagingk3s.i.p.nip.io

./install-cloudautomation-workshop.sh
```

## Executing some samples for the workshop

### Step 1: Deploy services end-2-end

```
keptn trigger delivery --project=delivery-demo --service=tnt-angr-svc --image=grabnerandi/simplenodeservice:1.0.0
```

### Step 2: Deploy services directly in production

```
keptn trigger delivery --project=delivery-demo --service=tnt-angr-svc --stage=production --image=grabnerandi/simplenodeservice:1.0.0
```

### Step 3: Deploy ALL services for ALL tenants in one go

```
./trigger-for-all-tenants.sh tenants.sh delivery-demo production grabnerandi/simplenodeservice:1.0.0
```

## Import Sample Dynatrace SLO Dashboard

In this directory you find the [default_qualitygate_dashboard.json](./scripts/default_qualitygate_dashboard.json). 
I suggest you import this one to your Dynatrace environment as you can use it as a template for the SLO-based Quality Gate tutorial.
The name can be: `KQG;project=dynatrace;stage=quality-gate;service=<YOURSERVICENAME>`