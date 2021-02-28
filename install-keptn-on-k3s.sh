#!/usr/bin/env bash

set -eu

DT_TENANT=${DT_TENANT:-none}
DT_API_TOKEN=${DT_API_TOKEN:-none}

PROVIDER="none"
BINDIR="/usr/local/bin"
KEPTNVERSION="0.7.3"
JMETER_SERVICE_BRANCH="feature/2552/jmeterextensions"
KEPTN_API_TOKEN="$(head -c 16 /dev/urandom | base64)"
MY_IP="none"
FQDN="none"
KEPTN_DOMAIN="none"
K3SKUBECTL=("${BINDIR}/k3s" "kubectl")
PREFIX="https"
PROM="false"
DYNA="false"
GITEA="false"
JMETER="false"
CERTS="selfsigned"
SLACK="false"
XIP="false"
DEMO="false"
GENERICEXEC="false"
BRIDGE_PASSWORD="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml
LE_STAGE=${LE_STAGE:-none}

#Gitea - default values
GIT_USER="keptn"
GIT_PASSWORD="keptn#R0cks"
GIT_SERVER="none"
GIT_DOMAIN="none"

# static vars
GIT_TOKEN="keptn-upstream-token"
TOKEN_FILE=$GIT_TOKEN.json

# keptn demo project defaults
KEPTN_QG_PROJECT="dynatrace"
KEPTN_QG_STAGE="quality-gate"
KEPTN_QG_SERVICE="demo"
KEPTN_PERFORMANCE_PROJECT="demo-performance"
KEPTN_PERFORMANCE_STAGE="performance"
KEPTN_PERFORMANCE_SERVICE="appundertest"
KEPTN_PERFORMANCE_EASYTRAVEL="easytravel"
KEPTN_REMEDIATION_PROJECT="demo-remediation"
KEPTN_REMEDIATION_STAGE="production"
KEPTN_REMEDIATION_SERVICE="default"
KEPTN_DELIVERY_PROJECT="demo-delivery"
KEPTN_DELIVERY_STAGE_DEV="dev"
KEPTN_DELIVERY_STAGE_STAGING="dev"
KEPTN_DELIVERY_SERVICE="simplenode"

function create_namespace {
  namespace="${1:-none}"
  if [[ "${namespace}" == "none" ]]; then
    echo "No Namespace given"
    exit 1
  fi

  if [[ ! $("${K3SKUBECTL[@]}" get namespace "$namespace") ]]; then
    "${K3SKUBECTL[@]}" create namespace "$namespace"
  fi
}

function check_delete_secret {
  secret="${1:-none}"
  namespace="${2:-keptn}"
  if [[ "${secret}" == "none" ]]; then
    echo "No Secret given"
    exit 1
  fi

  if [[ $("${K3SKUBECTL[@]}" get secret "$secret" -n "$namespace") ]]; then
    "${K3SKUBECTL[@]}" delete secret "$secret" -n "$namespace"
  fi

}

function get_keptn_token {
  echo "$(${K3SKUBECTL[@]} get secret keptn-api-token -n keptn -o jsonpath={.data.keptn-api-token} | base64 -d)"
}


function write_progress {
  status="${1:-default}"
  echo ""
  echo "#######################################>"
  echo "# ${status}"
  echo "#######################################>"
}


function get_ip {
  write_progress "Determining IP Address"
  if [[ "${MY_IP}" == "none" ]]; then
    if hostname -I > /dev/null 2>&1; then
      MY_IP="$(hostname -I | awk '{print $1}')"
    else
      echo "Could not determine ip, please specify manually"
      exit 1
    fi
  fi

  if [[ ${MY_IP} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Detected IP: ${MY_IP}"
  else
    echo "${MY_IP} is not a valid ip address"
    exit 1
  fi
}

function get_xip_address {
  address="${1:-none}"
  if [[ $address != none ]]; then
    echo "${address}.xip.io"
  else
    echo "No address given"
    exit 1
  fi
}

function get_fqdn {
  if [[ "$FQDN" == "none" ]]; then

    FQDN="${MY_IP}"

    if [[ "${LE_STAGE}" == "staging" ]] || [[ "${XIP}" == "true" ]]; then
      FQDN="$(get_xip_address "${MY_IP}")"
    fi
    if [[ "${LE_STAGE}" == "production" ]]; then
      echo "Issuing Production LetsEncrypt Certificates with xip.io as domain is not possible"
      exit 1
    fi
  fi

  KEPTN_DOMAIN="keptn.${FQDN}"
  GIT_DOMAIN="git.${FQDN}"
}

function apply_manifest {
  if [[ ! -z $1 ]]; then
    "${K3SKUBECTL[@]}" apply -f "${1}"
    if [[ $? != 0 ]]; then
      echo "Error applying manifest $1"
      exit 1
    fi
  fi
}

function apply_manifest_ns_keptn {
  if [[ ! -z $1 ]]; then
    "${K3SKUBECTL[@]}" apply -n keptn -f "${1}"
    if [[ $? != 0 ]]; then
      echo "Error applying manifest $1"
      exit 1
    fi
  fi
}

function get_k3s {
  write_progress "Installing K3s"
  curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable INSTALL_K3S_SYMLINK="skip" K3S_KUBECONFIG_MODE="644" sh -
}

function get_helm {
  write_progress "Installing Helm"

  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh
}

function check_k8s {
  started=false
  while [[ ! "${started}" ]]; do
    sleep 5
    if "${K3SKUBECTL[@]}" get nodes; then
      started=true
    fi
  done
}


function install_certmanager {
  write_progress "Installing Cert-Manager"
  create_namespace cert-manager

  helm upgrade cert-manager cert-manager --install --wait \
    --create-namespace --namespace=cert-manager \
    --repo="https://charts.jetstack.io" \
    --kubeconfig="${KUBECONFIG}" \
    --set installCRDs=true

  sleep 3
  cat << EOF | apply_manifest -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
  namespace: cert-manager
spec:
  selfSigned: {}
EOF

  check_delete_secret traefik-default-cert kube-system

  cat << EOF | apply_manifest -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-default
  namespace: kube-system
spec:
  secretName: traefik-default-cert
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
  - ${MY_IP}
EOF


if [[ "$CERTS" == "letsencrypt" ]]; then
  if [[ "$LE_STAGE" == "production" ]]; then
    ACME_SERVER="https://acme-v02.api.letsencrypt.org/directory"
  else
    ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
  fi

  cat << EOF | apply_manifest -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-issuer
spec:
  acme:
    email: $CERT_EMAIL
    server: $ACME_SERVER
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-issuer-account-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
fi
  "${K3SKUBECTL[@]}" rollout restart deployment traefik -n kube-system
  sleep 5
  echo "Waiting for Traefik to restart - 1st attempt (max 60s)"
  "${K3SKUBECTL[@]}" wait --namespace=kube-system --for=condition=Ready pods --timeout=60s -l app=traefik
}

function install_keptn {
  write_progress "Installing Keptn"
  helm upgrade keptn keptn --install --wait \
    --version="${KEPTNVERSION}" \
    --create-namespace --namespace=keptn \
    --repo="https://storage.googleapis.com/keptn-installer" \
    --kubeconfig="$KUBECONFIG"

  # Lets install the Statistics Service
  write_progress "Installing Keptn Statistics Service"
  apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/statistics-service/release-0.2.0/deploy/service.yaml"

    # Enable Monitoring support for either Prometheus or Dynatrace by installing the services and sli-providers
  if [[ "${PROM}" == "true" ]]; then
     write_progress "Installing Prometheus Service"
     apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/prometheus-service/release-0.3.6/deploy/service.yaml"
     apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/prometheus-sli-service/0.2.3/deploy/service.yaml "
  fi

  if [[ "${DYNA}" == "true" ]]; then
    write_progress "Installing Dynatrace Service & Monaco (Monitoring as Code)"
    create_namespace dynatrace

    check_delete_secret dynatrace
    "${K3SKUBECTL[@]}" create secret generic -n keptn dynatrace \
      --from-literal="DT_TENANT=$DT_TENANT" \
      --from-literal="DT_API_TOKEN=$DT_API_TOKEN" \
      --from-literal="KEPTN_API_URL=${PREFIX}://$KEPTN_DOMAIN/api" \
      --from-literal="KEPTN_API_TOKEN=$(get_keptn_token)" \
      --from-literal="KEPTN_BRIDGE_URL=${PREFIX}://$KEPTN_DOMAIN/bridge"

    # Installing core dynatrace services
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/dynatrace-service/0.10.3/deploy/service.yaml"
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/0.7.3/deploy/service.yaml"

    # Installing monaco service
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/monaco-service/release-0.2.1/deploy/service.yaml"

    # lets make Dynatrace the default SLI provider (feature enabled with lighthouse 0.7.2)
    "${K3SKUBECTL[@]}" create configmap lighthouse-config -n keptn --from-literal=sli-provider=dynatrace || true 
  fi

  if [[ "${GITEA}" == "true" ]]; then
    write_progress "Installing Gitea for upstream git"
    helm repo add gitea-charts https://dl.gitea.io/charts/

    echo "Create namespace for git"
    "${K3SKUBECTL[@]}" create ns git

    # always acceses git via http as we otherwise may have problem with self-signed certificate!
    GIT_SERVER="http://$GIT_DOMAIN"
    curl -fsSL -o helm-gitea.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/gitea/helm-gitea.yaml

    # Download helm yaml
    sed -e 's~domain.placeholder~'"$GIT_DOMAIN"'~' \
        -e 's~GIT_USER.placeholder~'"$GIT_USER"'~' \
        -e 's~GIT_PASSWORD.placeholder~'"$GIT_PASSWORD"'~' \
        helm-gitea.yaml > helm-gitea_gen.yaml

    echo "Install gitea via Helmchart"
    helm install gitea gitea-charts/gitea -f helm-gitea_gen.yaml --namespace git --kubeconfig="${KUBECONFIG}"
    
    write_progress "Configuring Gitea Ingress Object (${GIT_DOMAIN})"

  cat << EOF |  "${K3SKUBECTL[@]}" apply -n git -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitea-ingress
  annotations:
    cert-manager.io/cluster-issuer: $CERTS-issuer
spec:
  tls:
  - hosts:
    - "${GIT_DOMAIN}"
    secretName: keptn-tls
  rules:
    - host: "${GIT_DOMAIN}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitea-http
                port: 
                  number: 3000
EOF

    write_progress "Waiting for Gitea pods to be ready (max 5 minutes)"
    "${K3SKUBECTL[@]}" wait --namespace=git --for=condition=Ready pods --timeout=300s --all    
  fi

  if [[ "${GENERICEXEC}" == "true" ]]; then
    write_progress "Installing Generic Executor Service"

    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/generic-executor-service/master/deploy/service.yaml"
  fi

  if [[ "${SLACK}" == "true" ]]; then
    write_progress "Installing SlackBot Service"
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/slackbot-service/0.2.0/deploy/slackbot-service.yaml"

    check_delete_secret slackbot
    "${K3SKUBECTL[@]}" create secret generic -n keptn slackbot --from-literal="slackbot-token=$SLACKBOT_TOKEN"
  fi

  # Installing JMeter Extended Service
  if [[ "${JMETER}" == "true" ]]; then
    write_progress "Installing JMeter Service"
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/deploy/service.yaml"
  fi

  write_progress "Configuring Keptn Ingress Object (${KEPTN_DOMAIN})"

  cat << EOF |  "${K3SKUBECTL[@]}" apply -n keptn -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keptn-ingress
  annotations:
    cert-manager.io/cluster-issuer: $CERTS-issuer
spec:
  tls:
  - hosts:
    - "${KEPTN_DOMAIN}"
    secretName: keptn-tls
  rules:
    - host: "${KEPTN_DOMAIN}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-gateway-nginx
                port: 
                  number: 80
EOF

  write_progress "Waiting for Keptn pods to be ready (max 5 minutes)"
  "${K3SKUBECTL[@]}" wait --namespace=keptn --for=condition=Ready pods --timeout=300s --all

  write_progress "Waiting for certificates to be ready (max 5 minutes)"
  "${K3SKUBECTL[@]}" wait --namespace=keptn --for=condition=Ready certificate keptn-tls --timeout=300s
}

function install_keptncli {
  KEPTN_API_TOKEN="$(get_keptn_token)"

  echo "Installing and Authenticating Keptn CLI"
  curl -sL https://get.keptn.sh | sudo -E bash
  keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${PREFIX}://$KEPTN_DOMAIN/api"
}

# Following are functions based on Gitea Documentation
# https://gitea.com/gitea/helm-chart/#configuration

# Load git vars

# Create Token
gitea_createApiToken(){
    echo "Creating token for $GIT_USER from $GIT_SERVER"
    curl -vk --user $GIT_USER:$GIT_PASSWORD \
    -X POST "$GIT_SERVER/api/v1/users/$GIT_USER/tokens" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8" \
    -d "{ \"name\": \"$GIT_TOKEN\" }" -o $TOKEN_FILE
}

gitea_getApiTokens(){
    echo "Get tokens for $GIT_USER from $GIT_SERVER"
    curl -vk --user $GIT_USER:$GIT_PASSWORD \
    -X GET "$GIT_SERVER/api/v1/users/$GIT_USER/tokens" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8"
}

gitea_deleteApiToken(){
    echo "Deleting token for $GIT_USER from $GIT_SERVER"
    curl -vk --user $GIT_USER:$GIT_PASSWORD \
    -X DELETE "$GIT_SERVER/api/v1/users/$GIT_USER/tokens/$TOKEN_ID" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8" 
}

gitea_readApiTokenFromFile() {
    if [ ! -f "$TOKEN_FILE" ]; then
        gitea_createApiToken 
    fi 

    if [ -f "$TOKEN_FILE" ]; then
        echo "Reading token from file $TOKEN_FILE"
        TOKENJSON=$(cat $TOKEN_FILE)
        API_TOKEN=$(echo $TOKENJSON | jq -r '.sha1')
        TOKEN_ID=$(echo $TOKENJSON | jq -r '.id')
        echo "tokenId: $TOKEN_ID hash: $API_TOKEN"
    else 
        echo "Cant get Git Token!"
    fi
}

gitea_createKeptnRepos() {
    echo "Creating repositories for Keptn projects "
    for project in `keptn get projects | awk '{ if (NR!=1) print $1}'`;
    do 
        gitea_createKeptnRepo $project
    done
}

gitea_updateKeptnRepo(){
    KEPTN_PROJECT=$1
    keptn update project $KEPTN_PROJECT --git-user=$GIT_USER --git-token=$API_TOKEN --git-remote-url=$GIT_SERVER/$GIT_USER/$KEPTN_PROJECT.git
}

gitea_createKeptnRepoManually(){
    gitea_readApiTokenFromFile
    gitea_createKeptnRepo $1
}

gitea_createKeptnRepo(){
    echo "Creating and migrating Keptn project to self-hosted git for $1"
    gitea_createGitRepo $1
    gitea_updateKeptnRepo $1
}

gitea_createGitRepo(){
    echo "Create repo for project $1"
    # Create Repo with Token
    curl -k -X POST "$GIT_SERVER/api/v1/user/repos?access_token=$API_TOKEN" \
    -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{ \"auto_init\": false, \"default_branch\": \"master\", \"name\": \"$1\", \"private\": false}"
}


function install_demo_dynatrace {
  write_progress "Installing Dynatrace Demo Projects"

  # ==============================================================================================
  # Demo 1: Create a quality-gate project called "dynatrace"
  # Setup based on https://github.com/keptn-contrib/dynatrace-sli-service/tree/master/dashboard
  # This project also enables the auto-synchronization capability as explained here: https://github.com/keptn-contrib/dynatrace-service#synchronizing-service-entities-detected-by-dynatrace
  # ==============================================================================================
  DYNATRACE_TENANT="https://${DT_TENANT}"
  DYNATRACE_ENDPOINT=$DYNATRACE_TENANT/api/config/v1/dashboards
  DYNATRACE_TOKEN="${DT_API_TOKEN}"

  KEPTN_ENDPOINT="${PREFIX}://${KEPTN_DOMAIN}"
  KEPTN_BRIDGE_PROJECT="${KEPTN_ENDPOINT}/bridge/project/${KEPTN_QG_PROJECT}"
  KEPTN_BRIDGE_PROJECT_ESCAPED="${KEPTN_BRIDGE_PROJECT//\//\\/}"

  mkdir -p keptn/${KEPTN_QG_PROJECT}/dynatrace
  cat > keptn/${KEPTN_QG_PROJECT}/shipyard.yaml << EOF
stages:
- name: "${KEPTN_QG_STAGE}"
  test_strategy: "performance"
EOF

  echo "Create Keptn Project: ${KEPTN_QG_PROJECT}"
  keptn create project "${KEPTN_QG_PROJECT}" --shipyard=keptn/${KEPTN_QG_PROJECT}/shipyard.yaml

  echo "Create Keptn Service: ${KEPTN_QG_SERVICE}"
  keptn create service "${KEPTN_QG_SERVICE}" --project="${KEPTN_QG_PROJECT}"
  
  echo "Adding Dynatrace SLI/SLO Dashboard Monaco Files for ${KEPTN_QG_PROJECT}.${KEPTN_QG_STAGE}.${KEPTN_QG_SERVICE}"
  mkdir -p keptn/${KEPTN_QG_PROJECT}/monaco/projects/${KEPTN_QG_SERVICE}/dashboard
  curl -fsSL -o keptn/${KEPTN_QG_PROJECT}/monaco/projects/${KEPTN_QG_SERVICE}/dashboard/qgdashboard.json https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/monaco/dashboard/qgdashboard.json
  curl -fsSL -o keptn/${KEPTN_QG_PROJECT}/monaco/projects/${KEPTN_QG_SERVICE}/dashboard/qgdashboard.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/monaco/dashboard/qgdashboard.yaml
  
  # Replace one placeholder with the keptn bridge url
  sed -i "s/\${KEPTN_BRIDGE_PROJECT}/${KEPTN_BRIDGE_PROJECT_ESCAPED}/" keptn/${KEPTN_QG_PROJECT}/monaco/projects/${KEPTN_QG_SERVICE}/dashboard/qgdashboard.json

  # upload monaco files
  keptn add-resource --project="${KEPTN_QG_PROJECT}" --resource=keptn/${KEPTN_QG_PROJECT}/monaco/projects/${KEPTN_QG_SERVICE}/dashboard/qgdashboard.json --resourceUri=dynatrace/projects/${KEPTN_QG_SERVICE}/dashboard/qgdashboard.json
  keptn add-resource --project="${KEPTN_QG_PROJECT}" --resource=keptn/${KEPTN_QG_PROJECT}/monaco/projects/${KEPTN_QG_SERVICE}/dashboard/qgdashboard.yaml --resourceUri=dynatrace/projects/${KEPTN_QG_SERVICE}/dashboard/qgdashboard.yaml

  echo "Add dynatrace.conf.yaml to enable SLI/SLO Dashboard query"
  cat > keptn/${KEPTN_QG_PROJECT}/dynatrace/dynatrace.conf.yaml << EOF
spec_version: '0.1.0'
dashboard: query
attachRules:
  tagRule:
  - meTypes:
    - SERVICE
    tags:
    - context: CONTEXTLESS
      key: keptn_service
      value: \$SERVICE
    - context: CONTEXTLESS
      key: keptn_managed
EOF
  keptn add-resource --project="${KEPTN_QG_PROJECT}" --resource=keptn/${KEPTN_QG_PROJECT}/dynatrace/dynatrace.conf.yaml --resourceUri=dynatrace/dynatrace.conf.yaml


  echo "Send keptn configuration change to apply config changes"

  echo "Run first Dynatrace Quality Gate"
  keptn send event start-evaluation --project="${KEPTN_QG_PROJECT}" --stage="${KEPTN_QG_STAGE}" --service="${KEPTN_QG_SERVICE}"

  # ==============================================================================================
  # Demo 2: Performance as a Self-service Project
  # Creates a single stage project that will execute JMeter performance tests against any URL you give it
  # To get Keptn also send events to a Dynatrace Monitored Entity simply tag the entity with ${KEPTN_QG_STAGE}
  # ==============================================================================================
  mkdir -p keptn/${KEPTN_PERFORMANCE_PROJECT}/dynatrace
  mkdir -p keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter
  cat > keptn/${KEPTN_PERFORMANCE_PROJECT}/shipyard.yaml << EOF
stages:
- name: "${KEPTN_PERFORMANCE_STAGE}"
EOF

  echo "Create Keptn Project: ${KEPTN_PERFORMANCE_PROJECT}"
  keptn create project "${KEPTN_PERFORMANCE_PROJECT}" --shipyard=keptn/${KEPTN_PERFORMANCE_PROJECT}/shipyard.yaml

  echo "Create Keptn Service: ${KEPTN_PERFORMANCE_SERVICE}"
  keptn create service "${KEPTN_PERFORMANCE_SERVICE}" --project="${KEPTN_PERFORMANCE_PROJECT}"

  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/jmeter.conf.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/jmeter.conf.yaml
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basiccheck.jmx https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/basiccheck.jmx
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basiccheck_withdtmint.jmx https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/basiccheck_withdtmint.jmx
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload.jmx https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/basicload.jmx
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload_withdtmint.jmx https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/basicload_withdtmint.jmx
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/jmeter.conf.yaml --resourceUri=jmeter/jmeter.conf.yaml
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basiccheck.jmx --resourceUri=jmeter/basiccheck.jmx
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basiccheck_withdtmint.jmx --resourceUri=jmeter/basiccheck_withdtmint.jmx
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload.jmx --resourceUri=jmeter/basicload.jmx
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload_withdtmint.jmx --resourceUri=jmeter/basicload_withdtmint.jmx

  echo "Create Keptn Service: ${KEPTN_PERFORMANCE_EASYTRAVEL}"
  keptn create service "${KEPTN_PERFORMANCE_EASYTRAVEL}" --project="${KEPTN_PERFORMANCE_PROJECT}"

  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/easytravel-jmeter.conf.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/easytravel-jmeter.conf.yaml
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/easytravel-classic-random-book.jmx https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/easytravel-classic-random-book.jmx
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/easytravel-users.txt https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/jmeter/easytravel-users.txt
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --stage=${KEPTN_PERFORMANCE_STAGE} --service=${KEPTN_PERFORMANCE_EASYTRAVEL} --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/easytravel-jmeter.conf.yaml --resourceUri=jmeter/jmeter.conf.yaml
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --stage=${KEPTN_PERFORMANCE_STAGE} --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/easytravel-classic-random-book.jmx --resourceUri=jmeter/easytravel-classic-random-book.jmx
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --stage=${KEPTN_PERFORMANCE_STAGE} --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/easytravel-users.txt --resourceUri=jmeter/easytravel-users.txt

  cat > keptn/${KEPTN_PERFORMANCE_PROJECT}/dynatrace/dynatrace.conf.yaml << EOF
spec_version: '0.1.0'
dashboard: query
attachRules:
  tagRule:
  - meTypes:
    - SERVICE
    tags:
    - context: CONTEXTLESS
      key: \$SERVICE
EOF

  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/dynatrace/dynatrace.conf.yaml --resourceUri=dynatrace/dynatrace.conf.yaml

  # adding SLI/SLO
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/dynatrace/sli.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/performance_sli.yaml
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/slo.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/performance_slo.yaml
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/dynatrace/sli.yaml --resourceUri=dynatrace/sli.yaml
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --stage="${KEPTN_PERFORMANCE_STAGE}" --service="${KEPTN_PERFORMANCE_SERVICE}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/slo.yaml --resourceUri=slo.yaml

  # Download helper files to send a deployment finished event
  echo "Downloading helper script senddeployfinished.sh"
  curl -fsSL -o senddeployfinished.sh https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/events/senddeploymentfinished.sh
  curl -fsSL -o deployment.finished.event.placeholders.json https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/events/deployment.finished.event.placeholder.json
  chmod +x senddeployfinished.sh

  # ==============================================================================================
  # Demo 3: Auto-Remediation
  # Creates a single stage project with a service that will map to all incoming problem types, e.g: infrastructure, applcation ...
  # The service will have its own remediation.yaml to execute remediation scripts
  # This demo will leverage the generic-executor-service to execute bash or python scripts for remediation
  # ==============================================================================================
  mkdir -p keptn/${KEPTN_REMEDIATION_PROJECT}/dynatrace
  mkdir -p keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor
  cat > keptn/${KEPTN_REMEDIATION_PROJECT}/shipyard.yaml << EOF
stages:
- name: "${KEPTN_REMEDIATION_STAGE}"
  remediation_strategy: automated
EOF

  echo "Create Keptn Project: ${KEPTN_REMEDIATION_PROJECT}"
  keptn create project "${KEPTN_REMEDIATION_PROJECT}" --shipyard=keptn/${KEPTN_REMEDIATION_PROJECT}/shipyard.yaml

  echo "Create Keptn Service: ${KEPTN_REMEDIATION_SERVICE}"
  keptn create service "${KEPTN_REMEDIATION_SERVICE}" --project="${KEPTN_REMEDIATION_PROJECT}"

  cat > keptn/${KEPTN_REMEDIATION_PROJECT}/dynatrace/dynatrace.conf.yaml << EOF
spec_version: '0.1.0'
dashboard: query
EOF

  keptn add-resource --project="${KEPTN_REMEDIATION_PROJECT}" --resource=keptn/${KEPTN_REMEDIATION_PROJECT}/dynatrace/dynatrace.conf.yaml --resourceUri=dynatrace/dynatrace.conf.yaml

  # remediation.yaml and remediation scripts
  curl -fsSL -o keptn/${KEPTN_REMEDIATION_PROJECT}/remediation.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/remediation.yaml
  curl -fsSL -o keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.firstaction.sh https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/action.triggered.firstaction.sh
  curl -fsSL -o keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.secondaction.sh https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/action.triggered.secondaction.sh
  curl -fsSL -o keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.escalate.sh https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/action.triggered.escalate.sh
  curl -fsSL -o keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.validatedns.sh https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/action.triggered.validatedns.sh
  curl -fsSL -o keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.poweroutageaction.py https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/action.triggered.poweroutageaction.py
  keptn add-resource --project="${KEPTN_REMEDIATION_PROJECT}" --stage="${KEPTN_REMEDIATION_STAGE}" --service="${KEPTN_REMEDIATION_SERVICE}" --resource=keptn/${KEPTN_REMEDIATION_PROJECT}/remediation.yaml --resourceUri=remediation.yaml
  keptn add-resource --project="${KEPTN_REMEDIATION_PROJECT}" --resource=keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.firstaction.sh --resourceUri=generic-executor/action.triggered.firstaction.sh
  keptn add-resource --project="${KEPTN_REMEDIATION_PROJECT}" --resource=keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.secondaction.sh --resourceUri=generic-executor/action.triggered.secondaction.sh
  keptn add-resource --project="${KEPTN_REMEDIATION_PROJECT}" --resource=keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.escalate.sh --resourceUri=generic-executor/action.triggered.escalate.sh
  keptn add-resource --project="${KEPTN_REMEDIATION_PROJECT}" --resource=keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.validatedns.sh --resourceUri=generic-executor/action.triggered.validatedns.sh
  keptn add-resource --project="${KEPTN_REMEDIATION_PROJECT}" --resource=keptn/${KEPTN_REMEDIATION_PROJECT}/generic-executor/action.triggered.poweroutageaction.py --resourceUri=generic-executor/action.triggered.poweroutageaction.py

  # Download helper files to create a dynatrace problem
  echo "Downloading helper scripts: createdtproblem.sh, createdtnotification.sh"
  curl -fsSL -o createdtproblem.sh https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/createdtproblem.sh
  chmod +x createdtproblem.sh
  curl -fsSL -o createdtnotification.sh https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/createdtnotification.sh
  chmod +x createdtnotification.sh

  # last step is to setup upstream gits
  if [[ "${GITEA}" == "true" ]]; then
    gitea_readApiTokenFromFile
    gitea_createKeptnRepo "dynatrace"
    gitea_createKeptnRepo "demo-performance"
    gitea_createKeptnRepo "demo-remediation"
  fi

}

function install_demo {
  if [[ "${DEMO}" == "dynatrace" ]]; then
    install_demo_dynatrace
  fi 
}

function print_config {
  write_progress "Keptn Deployment Summary"
  BRIDGE_USERNAME="$(${K3SKUBECTL[@]} get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_USERNAME} | base64 -d)"
  BRIDGE_PASSWORD="$(${K3SKUBECTL[@]} get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_PASSWORD} | base64 -d)"
  KEPTN_API_TOKEN="$(get_keptn_token)"

  echo "API URL   :      ${PREFIX}://${KEPTN_DOMAIN}/api"
  echo "Bridge URL:      ${PREFIX}://${KEPTN_DOMAIN}/bridge"
  echo "Bridge Username: $BRIDGE_USERNAME"
  echo "Bridge Password: $BRIDGE_PASSWORD"
  echo "API Token :      $KEPTN_API_TOKEN"

if [[ "${GITEA}" == "true" ]]; then
  echo "Git Server:      $GIT_SERVER"
  echo "Git User:        $GIT_USER"
  echo "Git Password:    $GIT_PASSWORD"
fi

  if [[ "${DEMO}" == "dynatrace" ]]; then
  write_progress "Dynatrace Demo Summary: 3 Use Cases to explore"
  cat << EOF
3 Dynatrace Demo projects have been created, the Keptn CLI has been downloaded and configured and a first demo quality gate was already executed.

For the Quality Gate Use case you can do this::
1: Open the Keptn's Bridge for your Quality Gate Project: 
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_QG_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: Run another Quality Gate via: 
   keptn send event start-evaluation --project=${KEPTN_QG_PROJECT} --stage=${KEPTN_QG_STAGE} --service=${KEPTN_QG_SERVICE}
3: Automatically synchronize your Dynatrace monitored services with Keptn by adding the 'keptn_managed' and 'keptn_service:SERVICENAME' tag
   More details here: https://github.com/keptn-contrib/dynatrace-service#synchronizing-service-entities-detected-by-dynatrace

For the Performance as a Self-Service Demo we have created a project that contains a simple JMeter test that can test a single URL.
Here are 3 things you can do:
1: Open the Keptn's Bridge for your Performance Project:
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_PERFORMANCE_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: In Dynatrace pick a service you want to run a simple test against and add the manual label: ${KEPTN_PERFORMANCE_SERVICE}
3: (optional) Create an SLO-Dashboard in Dynatrace with the name: KQG;project=${KEPTN_PERFORMANCE_PROJECT};service=${KEPTN_PERFORMANCE_SERVICE};stage=${KEPTN_PERFORMANCE_STAGE}
4: Trigger a Performance test for an application that is accessible from this machine, e.g. http://yourapp/yoururl
   ./senddeployfinished.sh ${KEPTN_PERFORMANCE_PROJECT} ${KEPTN_PERFORMANCE_STAGE} ${KEPTN_PERFORMANCE_SERVICE} performance_withdtmint http://yourapp/yoururl
5: Watch data in Dynatrace as the test gets executed and watch the Quality Gate in Keptn after test execution is done!

For the Auto-Remediation Demo we have created project ${KEPTN_REMEDIATION_PROJECT} that contains a default remediation.yaml and some bash and python scripts
In order for this to work do
1: Create a new Problem Notification Integration as explained in the readme
2: Either force Dynatrace to open a problem ticket, create one through the API or execute createdtproblem.sh
3: Watch the auto-remediation actions in Keptn's bridge
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_REMEDIATION_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD

Explore more Dynatrace related tutorials on https://tutorials.keptn.sh

EOF

  else     
  cat << EOF
The Keptn CLI has already been installed and authenticated. To use keptn here some sample commands
$ keptn status
$ keptn create project myfirstproject --shipyard=./shipyard.yaml

EOF
  fi 

  cat << EOF
If you want to install the Keptn CLI somewhere else - here the description:
- Install the keptn CLI: curl -sL https://get.keptn.sh | sudo -E bash
- Authenticate: keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${PREFIX}://$KEPTN_DOMAIN/api"

If you want to uninstall Keptn and k3s simply type: k3s-uninstall.sh!
After that also remove the demo files that were downloaded in your local working directory!

Now go and enjoy Keptn!
EOF

}

function main {
  while true; do
  case "${1:-default}" in
    --ip)
        MY_IP="${2}"
        shift 2
      ;;
    --provider)
        PROVIDER="${2}"
        case "${PROVIDER}" in
          gcp)
            echo "Provider: GCP"
            MY_IP="$(curl -Ls -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
            shift 2
            ;;
          aws)
            echo "Provider: AWS"
            MY_IP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
            shift 2
            ;;
          digitalocean)
            MY_IP="$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)"
            shift 2
            ;;
          *)
            echo "Unknown Provider given"
            exit 1
            ;;
        esac
        ;;
    --fqdn)
	FQDN="${2}"
	shift 2
      ;;
    --letsencrypt)
        echo "Will try to create LetsEncrypt certs"
        CERTS="letsencrypt"
        if [[ "$CERT_EMAIL" == "" ]]; then
          echo "Enabling LetsEncrpyt Support requires you to set CERT_EMAIL"
          exit 1
        fi
        if [[ "$LE_STAGE" != "production" ]]; then
          echo "Be aware that this will issue staging certificates"
        fi

        shift
        ;;
    --use-xip)
        echo "Using xip.io"
        XIP="true"
        shift
        ;;
    --with-jmeter)
        echo "Enabling JMeter Support"
        JMETER="true"
        shift
        ;;
    --with-prometheus)
        echo "Enabling Prometheus Support"
        PROM="true"
        shift
        ;;
    --with-dynatrace)
        DYNA="true"
        echo "Enabling Dynatrace Support: Requires you to set DT_TENANT, DT_API_TOKEN"
        if [[ "$DT_TENANT" == "none" ]]; then
          echo "You have to set DT_TENANT to your Tenant URL, e.g: abc12345.dynatrace.live.com or yourdynatracemanaged.com/e/abcde-123123-asdfa-1231231"
          echo "To learn more about the required settings please visit https://keptn.sh/docs/0.7.x/monitoring/dynatrace/install"
          exit 1
        fi
        if [[ "$DT_API_TOKEN" == "none" ]]; then
          echo "You have to set DT_API_TOKEN to a Token that has read/write configuration, access metrics, log content and capture request data priviliges"
          echo "If you want to learn more please visit https://keptn.sh/docs/0.7.x/monitoring/dynatrace/install"
          exit 1
        fi

        # Adding output as following curl may fail if DT_TENANT is resulting in an invalid curl
        echo "Running a check if Dynatrace API is reachable on https://$DT_TENANT/api/v1/config/clusterversion"
        echo "If script stops here please double check your DT_TENANT. It should be e,g: abc12345.dynatrace.live.com or yourdynatracemanaged.com/e/abcde-123123-asdfa-1231231"

        # Validate tenant and token is correct
        status=$(curl --request GET \
             --url "https://$DT_TENANT/api/v1/config/clusterversion" \
             --header "Authorization: Api-Token $DT_API_TOKEN" \
             --write-out %{http_code} --silent --output /dev/null)
        if [[ $status != 200 ]]; then
          echo "Couldnt connect to the Dynatrace API with provided DT_TENANT & DT_API_TOKEN"
          echo "Please double check the URL to not include leading https:// and double check your API_TOKEN priviliges"
          echo "To try this yourself try to get to: https://$DT_TENANT/api/v1/config/clusterversion"
          exit 1
        fi
        shift
        ;;
    --with-gitea)
       GITEA="true"
       shift
       ;;
    --with-demo)
        DEMO="${2}"
        if [[ $DEMO != "dynatrace" ]]; then 
          echo "--with-demo parameter currently supports: dynatrace. Value passed is not allowed"
          exit 1
        fi 

        # need to make sure we install the generic exector service for our demo as well as jmeter
        GENERICEXEC="true"
        JMETER="true"

        echo "Demo: Installing demo projects for ${DEMO}"
        shift 2
        ;;
    --with-slackbot)
        SLACK="true"
        echo "Enabling Slackbot: Requires secret 'slackbot' with slackbot-token to be set!"
        if [[ $SLACKBOT_TOKEN == "" ]]; then
          echo "You have to set the env variable SLACKBOT_TOKEN to the token for your Slackbot"
          echo "Find more information here: https://github.com/keptn-sandbox/slackbot-service"
          exit 1
        fi
        shift
        ;;
    *)
      break
      ;;
  esac
  done

  # Check pre-req of jq
  if ! [ -x "$(command -v jq)" ]; then
    echo 'Error: jq is not installed.' >&2
    exit 1
  fi
  if ! [ -x "$(command -v curl)" ]; then
    echo 'Error: curl is not installed.' >&2
    exit 1
  fi

  get_ip
  get_fqdn
  get_k3s
  get_helm
  check_k8s
  install_certmanager
  install_keptn
  install_keptncli
  install_demo  
  print_config
}

main "${@}"
