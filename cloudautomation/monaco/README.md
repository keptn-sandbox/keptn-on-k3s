# Dynatrace Monaco projects to support the workshop

The Cloud Automation Workshop contains several hands-on exercises. While the goal is to walk through them manually, e.g: create SLOs, create dashboards, .. one goal of the workshop is to also show how through the use of Monaco we can automate the configuration of SLOs, Dashboards, Management Zones, ...

This Monaco folder contains monaco projects that can be used to
1. Setup: Global dashboards and settings needed to run the workshop
2. Lab 1: Creating SLOs and SLO dashboards
3. Lab 2: Release Validation dashboard
4. Lab 3: Quality Gate dashboard
5. Delete: an option to delete configurations


## Usage: Setup your Dynatrace environment prior to the workshop

Following enviornment variables need to be set

1. **DT_TENANT**: hostname of your SaaS or managed environment, e.g: abc12345.live.dynatrace.com
2. **DT_API_TOKEN**: Dynatrace API Token
2. **KEPTN_CONTROL_PLANE_DOMAIN**: hostname of your Cloud Automation enviornment, e.g: abc12345.cloudautomation.live.dynatrace.com
3. **OWNER_EMAIL**: The username (=email) of your Dynatrace user. It will be used to create dashboards in your tenant

```
export OWNER=youremail@domain.com
export DT_TENANT=abc12345.live.dynatrace.com
export DT_API_TOKEN=dt0c01.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
export KEPTN_CONTROL_PLANE_DOMAIN=abc12345.cloudautomation.live.dynatrace.com
monaco -e environment.yaml projects/setup
```

## Usage: Create configurations for the labs

The following explain the individual lab projects and how to trigger them for individual workshop tenants. If you want to run them for every tenant in your tenants.sh you can also use the helper script `monaco-for-all-tenants.sh` that you can find in the scripts folder. It will basically iterate through your tenants.sh list of tenant and execute monaco for each TENANT!

### Lab 1: Create SLOs and SLO dashboard

Following enviornment variables need to be set
1. **TENANT_ID**: The workshop tenant you want to create the configuraitons for, e.g: aapl, goog, ... -> whatever you have in your tenants.sh
2. **OWNER_EMAIL**: The username (=email) of your Dynatrace user. It will be used to create dashboards in your tenant

```
export OWNER=youremail@domain.com
export TENANT=aapl
monaco -e environment.yaml -p lab1 projects
```

### Lab 2: Release Validation dashboards

Following enviornment variables need to be set
1. **TENANT_ID**: The workshop tenant you want to create the configuraitons for, e.g: aapl, goog, ... -> whatever you have in your tenants.sh
2. **OWNER_EMAIL**: The username (=email) of your Dynatrace user. It will be used to create dashboards in your tenant

```
export OWNER=youremail@domain.com
export TENANT=aapl
monaco -e environment.yaml -p lab2 projects
```

### Lab 3: SLO-based Quality Gates

Following enviornment variables need to be set
1. **TENANT_ID**: The workshop tenant you want to create the configuraitons for, e.g: aapl, goog, ... -> whatever you have in your tenants.sh
2. **OWNER_EMAIL**: The username (=email) of your Dynatrace user. It will be used to create dashboards in your tenant

```
export OWNER=youremail@domain.com
export TENANT=aapl
monaco -e environment.yaml -p lab3 projects
```

## DELETE the configuration for a specific project

THIS WILL DELETE ALL CONFIGURATIONS created in Lab 1, lab 2 & lab 3 for the specified tenant

Following enviornment variables need to be set
1. **TENANT_ID**: The workshop tenant you want to create the configuraitons for, e.g: aapl, goog, ... -> whatever you have in your tenants.sh

```
export OWNER=youremail@domain.com
export TENANT=aapl
sed -e 's~TENANT_ID~'"$TENANT_ID"'~' \
  projects/delete/delete.tmpl > projects/delete/delete.yaml
monaco -e environment.yaml projects/delete
rm projects/delete/delete.yaml
```

If you want to DELETE CONFIG FOR ALL TENANTS simply use `monaco-for-all-tenants.sh` from the scripts folder and specify the project `delete`