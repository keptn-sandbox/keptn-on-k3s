#!/usr/bin/env bash

set -eu

# Keptn Version Information
KEPTNVERSION="0.8.1"
KEPTN_TYPE="controlplane"
KEPTN_DELIVERYPLANE=false
KEPTN_EXECUTIONPLANE=false
KEPTN_CONTROLPLANE=true

ISTIO_VERSION="1.9.1"
INGRESS_PORT="80"
INGRESS_PROTOCOL="http"
ISTIO_GATEWAY="public-gateway.istio-system"

ARGO_ROLLOUTS_VERSION="stable"

# For execution plane these are the env-variables that identify the keptn control plane
# KEPTN_CONTROL_PLANE_DOMAIN=""
# KEPTN_CONTROL_PLANE_API_TOKEN=""

# For execution plane here are the filters
# KEPTN_EXECUTION_PLANE_STAGE_FILTER=""
# KEPTN_EXECUTION_PLANE_SERVICE_FILTER=""
# KEPTN_EXECUTION_PLANE_PROJECT_FILTER=""
HELM_SERVICE_IMAGE=grabnerandi/helm-service # keptn/helm-service
# JMETER_SERVICE_VERSION="feature/2552/jmeterextensions" # is now installed automatically
JMETER_SERVICE_VERSION="0.8.0"
NEOLOAD_SERVICE_VERSION="0.8.0"
PROM_SERVICE_VERSION="release-0.4.0"
PROM_SLI_SERVICE_VERSION="release-0.3.0"
DT_SERVICE_VERSION="release-0.12.0"
DT_SLI_SERVICE_VERSION="release-0.9.0"
GENERICEXEC_SERVICE_VERSION="release-0.8.0"  # "release-0.3"
MONACO_SERVICE_VERSION="release-0.8.0"  # migratetokeptn08
ARGO_SERVICE_VERSION="release-0.8.0" # updates/finalize08

# Dynatrace Credentials
DT_TENANT=${DT_TENANT:-none}
DT_API_TOKEN=${DT_API_TOKEN:-none}
DT_PAAS_TOKEN=${DT_PAAS_TOKEN:-none}
OWNER_EMAIL=${OWNER_EMAIL:-none}




# Install Flags
PROVIDER="none"
MY_IP="none"
FQDN="none"
KEPTN_DOMAIN="none"
PREFIX="https"
CERTS="selfsigned"
CERT_EMAIL=${CERT_EMAIL:-none}
LE_STAGE=${LE_STAGE:-none}
XIP="false"
INSTALL_TYPE="all"  # "k3s", "keptn", "demo", "gitea"

PROM="false"
DYNA="false"
GITEA="false"
JMETER="false"
SLACK="false"
GENERICEXEC="false"
NEOLOAD="false"
DEMO="false"


# Keptn Credentials
KEPTN_API_TOKEN="$(head -c 16 /dev/urandom | base64)"
BRIDGE_PASSWORD="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

# k8s config
K3SVERSION="v1.19"
BINDIR="/usr/local/bin"
K3SKUBECTL=("${BINDIR}/k3s" "kubectl")
KUBECONFIG=/etc/rancher/k3s/k3s.yaml


#Gitea - default values
GIT_USER="keptn"
GIT_PASSWORD="keptn#R0cks"
GIT_SERVER="none"
GIT_DOMAIN="none"

# static vars
GIT_TOKEN="keptn-upstream-token"
TOKEN_FILE=$GIT_TOKEN.json
# Tricentis Neoload Credentials
NL_WEB_HOST=${NL_WEB_HOST:-none}
NL_WEBAPI_HOST=${NL_WEBAPI_HOST:-none}
NL_API_TOKEN=${NL_API_TOKEN:-none}
NL_ZONE_ID=${NL_ZONE_ID:-none}
NL_WEBUPLOAD_HOST=${NL_WEBUPLOAD_HOST:-none}
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
KEPTN_DELIVERY_STAGE_STAGING="staging"
KEPTN_DELIVERY_STAGE_PRODUCTION="production"
KEPTN_DELIVERY_SERVICE="simplenode"

KEPTN_ROLLOUT_PROJECT="demo-rollout"

KEPTN_ADV_PERFORMANCE_PROJECT="demo-adv-performance"
KEPTN_ADV_PERFORMANCE_STAGE="performance"
KEPTN_ADV_PERFORMANCE_SERVICE="appundertest"


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
  # always acceses git via http as we otherwise may have problem with self-signed certificate!
  GIT_SERVER="http://$GIT_DOMAIN"
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

function get_kubectl {
  if ! [ -x "$(command -v kubectl)" ]; then
    write_progress "Installing kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  fi  
}

function get_k3s {
  write_progress "Installing K3s (${K3SVERSION}) with NGINX instead of Traefik Ingress"
  curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL="${K3SVERSION}" INSTALL_K3S_SYMLINK="skip" K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--disable=traefik" sh -

  # set the kubeconfig
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  kubectl get pods -A

  # install ingress nginx
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update

  helm install ingress-nginx ingress-nginx/ingress-nginx  
}

# Installs Dynatrace OneAgent Operator on the k3s cluster
function get_oneagent {
  # only install if all dynatrace settings are specified
  if [ "$DT_TENANT" == "none" ]; then return; fi
  if [ "$DT_API_TOKEN" == "none" ]; then return; fi
  if [ "$DT_PAAS_TOKEN" == "none" ]; then return; fi

  helm repo add dynatrace https://raw.githubusercontent.com/Dynatrace/helm-charts/master/repos/stable
  "${K3SKUBECTL[@]}" create namespace dynatrace

  sed -e 's~DT_TENANT~'"$DT_TENANT"'~' \
    -e 's~DT_API_TOKEN~'"$DT_API_TOKEN"'~' \
    -e 's~DT_PAAS_TOKEN~'"$DT_PAAS_TOKEN"'~' \
    -e 's~DT_HOST_GROUP~'"$KEPTN_TYPE"'~' \
    ./files/dynatrace/oneagent_values.yaml > oneagent_values.yaml

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  helm install dynatrace-oneagent-operator \
    dynatrace/dynatrace-oneagent-operator -n\
    dynatrace --values oneagent_values.yaml

  rm oneagent_values.yaml
}

# Installs Dynatrace OneAgent Operator on the k3s cluster
function get_oneagent {
  # only install if all dynatrace settings are specified
  if [ "$DT_TENANT" == "none" ]; then return; fi
  if [ "$DT_API_TOKEN" == "none" ]; then return; fi
  if [ "$DT_PAAS_TOKEN" == "none" ]; then return; fi

  helm repo add dynatrace https://raw.githubusercontent.com/Dynatrace/helm-charts/master/repos/stable
  "${K3SKUBECTL[@]}" create namespace dynatrace

  sed -e 's~DT_TENANT~'"$DT_TENANT"'~' \
    -e 's~DT_API_TOKEN~'"$DT_API_TOKEN"'~' \
    -e 's~DT_PAAS_TOKEN~'"$DT_PAAS_TOKEN"'~' \
    -e 's~DT_HOST_GROUP~'"$KEPTN_TYPE"'~' \
    ./files/dynatrace/oneagent_values.yaml > oneagent_values.yaml

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  helm install dynatrace-oneagent-operator \
    dynatrace/dynatrace-oneagent-operator -n\
    dynatrace --values oneagent_values.yaml

  rm oneagent_values.yaml
}

function get_helm {
  write_progress "Installing Helm 3"

  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh
}

function get_argorollouts {
  echo "Install Argo Rollouts from ${ARGO_ROLLOUTS_VERSION}"

  # First installing Argo Rollouts itself
  "${K3SKUBECTL[@]}" create namespace argo-rollouts
  "${K3SKUBECTL[@]}" apply -n argo-rollouts -f https://raw.githubusercontent.com/argoproj/argo-rollouts/${ARGO_ROLLOUTS_VERSION}/manifests/install.yaml

  # now also installing the argo rollout extension for kubectl
  curl -LO https://github.com/argoproj/argo-rollouts/releases/${ARGO_ROLLOUTS_VERSION}/download/kubectl-argo-rollouts-linux-amd64
  sudo chmod +x ./kubectl-argo-rollouts-linux-amd64
  sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
}

function get_istio {
  ISTIO_EXISTS=$(kubectl get po -n istio-system | grep Running | wc | awk '{ print $1 }')
  if [[ "$ISTIO_EXISTS" -gt "0" ]]
  then
    echo "Istio already installed on k8s"
  else
    echo "Downloading and installing Istio ${ISTIO_VERSION}"
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
    sudo mv istio-${ISTIO_VERSION}/bin/istioctl /usr/local/bin/istioctl

    istioctl install -y

    write_progress "Configuring Istio Ingress Object"
    sed -e 's~issuer.placeholder~'"$CERTS"'~' \
        ./files/istio/istio-ingress.yaml > istio-ingress_gen.yaml
    "${K3SKUBECTL[@]}" apply -n istio-system -f istio-ingress_gen.yaml
    rm istio-ingress_gen.yaml

    "${K3SKUBECTL[@]}" apply -n istio-system -f ./files/istio/istio-gateway.yaml
  fi

  # TODO - maybe use FQDN instead of KEPTN_DOMAIN as prefix
  # Create ConfigMap Entry for keptn's helm service
  "${K3SKUBECTL[@]}" create configmap -n keptn ingress-config \
      --from-literal=ingress_hostname_suffix=${KEPTN_DOMAIN} \
      --from-literal=ingress_port=${INGRESS_PORT} \
      --from-literal=ingress_protocol=${INGRESS_PROTOCOL} \
      --from-literal=istio_gateway=${ISTIO_GATEWAY} \
      -oyaml --dry-run | kubectl replace -f -

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

  # Only install cert manager if we install control or delivery plane
  if [[ "${KEPTN_CONTROLPLANE}" == "false" ]] && [[ "${KEPTN_DELIVERYPLANE}" == "false" ]]; then
    return
  fi 

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

  check_delete_secret nginx-default-cert kube-system

  cat << EOF | apply_manifest -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx-default
  namespace: kube-system
spec:
  secretName: nginx-default-cert
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
      name: letsencrypt-issuer-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
fi
  "${K3SKUBECTL[@]}" rollout restart deployment ingress-nginx-controller
  sleep 5
  echo "Waiting for Nginx Ingress to restart - 1st attempt (max 60s)"
  "${K3SKUBECTL[@]}" wait --namespace=default --for=condition=Ready pods --timeout=60s --all
}

function install_keptn {

  if [[ "${KEPTN_CONTROLPLANE}" == "true" ]]; then
    write_progress "Installing Keptn Control Plane"
    helm upgrade keptn keptn --install --wait \
      --version="${KEPTNVERSION}" \
      --create-namespace --namespace=keptn \
      --repo="https://storage.googleapis.com/keptn-installer" \
      --set=continuous-delivery.enabled=false \
      --kubeconfig="$KUBECONFIG"
  fi 

  if [[ "${KEPTN_DELIVERYPLANE}" == "true" ]]; then
    write_progress "Installing Keptn for Continuous Delivery (Control & Execution Plane)"
    helm upgrade keptn keptn --install --wait \
      --version="${KEPTNVERSION}" \
      --create-namespace --namespace=keptn \
      --repo="https://storage.googleapis.com/keptn-installer" \
      --set=continuous-delivery.enabled=true \
     --set=continuous-delivery.helmService.image.repository="${HELM_SERVICE_IMAGE}" \
      --kubeconfig="$KUBECONFIG"

    # no need to additionally install jmeter as we install a delivery plane anyway!
    JMETER="false"

    # need to install Istio for Delivery Plane as we are potentially depoying sevices blue / green
    get_istio
    get_argorollouts

    # now we need to restart the helm service for it to pick up istio
    kubectl delete pod -n keptn --selector=app.kubernetes.io/name=helm-service

    # Install the Argo Service
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/argo-service/${ARGO_SERVICE_VERSION}/deploy/service.yaml"
  fi

  if [[ "${KEPTN_EXECUTIONPLANE}" == "true" ]]; then
    # following instructions from https://keptn.sh/docs/0.8.x/operate/multi_cluster/#install-keptn-execution-plane
    write_progress "Installing Keptn Execution Plane to connect to ${KEPTN_CONTROL_PLANE_DOMAIN}"

    # lets make sure the keptn namespace is created
    create_namespace "keptn"

    # need to install Istio for Execution Plane as we potentially deliver services with Blue / Green
    get_istio
    get_argorollouts

    # Install the Helm Service
    curl -fsSL -o /tmp/helm.values.yaml https://raw.githubusercontent.com/keptn/keptn/release-${KEPTNVERSION}/helm-service/chart/values.yaml
    yq w /tmp/helm.values.yaml "remoteControlPlane.enabled" "true"
    yq w /tmp/helm.values.yaml "remoteControlPlane.api.hostname" "${KEPTN_CONTROL_PLANE_DOMAIN}"
    yq w /tmp/helm.values.yaml "remoteControlPlane.api.token" "${KEPTN_CONTROL_PLANE_API_TOKEN}"
    yq w /tmp/helm.values.yaml "distributor.projectFilter" "${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
    yq w /tmp/helm.values.yaml "distributor.stageFilter" "${KEPTN_EXECUTION_PLANE_STAGE_FILTER}"
    yq w /tmp/helm.values.yaml "distributor.serviceFilter" "${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}"

    helm install helm-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/helm-service-${KEPTNVERSION}.tgz -n keptn-exec --create-namespace --values=/tmp/helm.values.yaml

    # Install the Argo Service
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/argo-service/${ARGO_SERVICE_VERSION}/deploy/service.yaml"

    # Install JMeter if the user wants to
    if [[ "${JMETER}" == "true" ]]; then
      curl -fsSL -o /tmp/jmeter.values.yaml https://raw.githubusercontent.com/keptn/keptn/release-${KEPTNVERSION}/jmeter-service/chart/values.yaml
      yq w /tmp/jmeter.values.yaml "remoteControlPlane.enabled" "true"
      yq w /tmp/jmeter.values.yaml "remoteControlPlane.api.hostname" "${KEPTN_CONTROL_PLANE_DOMAIN}"
      yq w /tmp/jmeter.values.yaml "remoteControlPlane.api.token" "${KEPTN_CONTROL_PLANE_API_TOKEN}"
      yq w /tmp/jmeter.values.yaml "distributor.projectFilter" "${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
      yq w /tmp/jmeter.values.yaml "distributor.stageFilter" "${KEPTN_EXECUTION_PLANE_STAGE_FILTER}"
      yq w /tmp/jmeter.values.yaml "distributor.serviceFilter" "${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}"

      helm install jmeter-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/jmeter-service-${KEPTNVERSION}.tgz -n keptn-exec --create-namespace --values=/tmp/helm.values.yaml
    fi

   if [[ "${NEOLOAD}" == "true" ]]; then
     install_neoload_service
   fi
  fi
 
  if [[ "${PROM}" == "true" ]]; then
     write_progress "Installing Prometheus Service"
     apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/prometheus-service/${PROM_SERVICE_VERSION}/deploy/service.yaml"
     apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/prometheus-sli-service/${PROM_SLI_SERVICE_VERSION}/deploy/service.yaml "
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
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/dynatrace-service/${DT_SERVICE_VERSION}/deploy/service.yaml"
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/${DT_SLI_SERVICE_VERSION}/deploy/service.yaml"

    # Installing monaco service
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/monaco-service/${MONACO_SERVICE_VERSION}/deploy/service.yaml"

    # lets make Dynatrace the default SLI provider (feature enabled with lighthouse 0.7.2)
    "${K3SKUBECTL[@]}" create configmap lighthouse-config -n keptn --from-literal=sli-provider=dynatrace || true 
  fi

  if [[ "${GITEA}" == "true" ]]; then
    write_progress "Installing Gitea for upstream git"
    helm repo add gitea-charts https://dl.gitea.io/charts/

    # removing any previous git-token files that might be left-over from a previous install
    if [ -f "${TOKEN_FILE}" ]; then 
      rm "${TOKEN_FILE}"     
    fi

    echo "Create namespace for git"
    "${K3SKUBECTL[@]}" create ns git

    # Download helm yaml
    sed -e 's~domain.placeholder~'"$GIT_DOMAIN"'~' \
        -e 's~GIT_USER.placeholder~'"$GIT_USER"'~' \
        -e 's~GIT_PASSWORD.placeholder~'"$GIT_PASSWORD"'~' \
        ./files/gitea/helm-gitea.yaml > helm-gitea_gen.yaml

    echo "Install gitea via Helmchart"
    helm install gitea gitea-charts/gitea -f helm-gitea_gen.yaml --namespace git --kubeconfig="${KUBECONFIG}"
    rm helm-gitea_gen.yaml
    
    write_progress "Configuring Gitea Ingress Object (${GIT_DOMAIN})"
    sed -e 's~domain.placeholder~'"$GIT_DOMAIN"'~' \
        -e 's~issuer.placeholder~'"$CERTS"'~' \
        ./files/gitea/gitea-ingress.yaml > gitea-ingress_gen.yaml
    "${K3SKUBECTL[@]}" apply -n git -f gitea-ingress_gen.yaml
    rm gitea-ingress_gen.yaml    

    write_progress "Waiting for Gitea pods to be ready (max 5 minutes)"
    "${K3SKUBECTL[@]}" wait --namespace=git --for=condition=Ready pods --timeout=300s --all    
  fi

  if [[ "${GENERICEXEC}" == "true" ]]; then
    write_progress "Installing Generic Executor Service"

    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/generic-executor-service/${GENERICEXEC_SERVICE_VERSION}/deploy/service.yaml"
  fi

  if [[ "${SLACK}" == "true" ]]; then
    write_progress "Installing SlackBot Service"
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/slackbot-service/0.2.0/deploy/slackbot-service.yaml"

    check_delete_secret slackbot
    "${K3SKUBECTL[@]}" create secret generic -n keptn slackbot --from-literal="slackbot-token=$SLACKBOT_TOKEN"
  fi

  # Installing JMeter Service on the control plane if requested!
  if [[ "${JMETER}" == "true" ]]; then
    write_progress "Installing JMeter Service"
    helm install jmeter-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/jmeter-service-${KEPTNVERSION}.tgz -n keptn --create-namespace
  fi

  # Installing JMeter Service on the control plane if requested!
  if [[ "${NEOLOAD}" == "true" ]]; then
    install_neoload_service
  fi

  write_progress "Configuring Keptn Ingress Object (${KEPTN_DOMAIN})"
  sed -e 's~domain.placeholder~'"$KEPTN_DOMAIN"'~' \
    -e 's~issuer.placeholder~'"$CERTS"'~' \
    ./files/keptn/keptn-ingress.yaml > keptn-ingress_gen.yaml
  "${K3SKUBECTL[@]}" apply -n keptn -f keptn-ingress_gen.yaml
  rm keptn-ingress_gen.yaml

  write_progress "Waiting for Keptn pods to be ready (max 5 minutes)"
  "${K3SKUBECTL[@]}" wait --namespace=keptn --for=condition=Ready pods --timeout=300s --all

  write_progress "Waiting for certificates to be ready (max 5 minutes)"
  "${K3SKUBECTL[@]}" wait --namespace=keptn --for=condition=Ready certificate keptn-tls --timeout=300s
}

function install_keptncli {
  KEPTN_API_TOKEN="$(get_keptn_token)"

  echo "Installing and Authenticating Keptn CLI"
  curl -sL https://get.keptn.sh | KEPTN_VERSION=${KEPTNVERSION} sudo -E bash
  keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${PREFIX}://$KEPTN_DOMAIN/api"
}

# Following are functions based on Gitea Documentation
# https://gitea.com/gitea/helm-chart/#configuration

# Load git vars

# Create Token
gitea_createApiToken(){
    echo "Creating token for $GIT_USER from $GIT_SERVER"
    curl -vkL --user $GIT_USER:$GIT_PASSWORD \
    -X POST "$GIT_SERVER/api/v1/users/$GIT_USER/tokens" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8" \
    -d "{ \"name\": \"$GIT_TOKEN\" }" -o $TOKEN_FILE
}

gitea_getApiTokens(){
    echo "Get tokens for $GIT_USER from $GIT_SERVER"
    curl -vkL --user $GIT_USER:$GIT_PASSWORD \
    -X GET "$GIT_SERVER/api/v1/users/$GIT_USER/tokens" \
    -H "accept: application/json" -H "Content-Type: application/json; charset=utf-8"
}

gitea_deleteApiToken(){
    echo "Deleting token for $GIT_USER from $GIT_SERVER"
    curl -vkL --user $GIT_USER:$GIT_PASSWORD \
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

install_neoload_service() {

   if [[  "$NL_WEB_HOST" == "none" ]]; then
     NL_WEB_HOST="neoload.saas.neotys.com"
   fi

   if [[ "$NL_WEBAPI_HOST" == "none" ]]; then
     NL_WEBAPI_HOST="neoload-api.saas.neotys.com"
   fi

   if [[  "$NL_WEBUPLOAD_HOST" == "none" ]]; then
     NL_WEBUPLOAD_HOST="neoload-files.saas.neotys.com"
   fi

   if [[ "$NL_API_TOKEN" == "none"  ]]; then
      echo "The NeoLoad API TOKEN has not be configure. create the NL_API_TOKEN environment variable first"
      exit 1
   fi

   if [[ "$NL_ZONE_ID" == "none" ]]; then
      echo "The NeoLoad Zone ID has not be configured. create the NL_ZONE_ID environment variable first"
      exit 1
   fi

   NAMESPACE="keptn"
   write_progress "Installing NeoLoad service"
   echo "Downloading and installing NeoLoad service ${NEOLOAD_SERVICE_VERSION}"

   if  [ ! -z "$GIT_USER" ] ;  then
     if  [ ! -z "$GIT_PASSWORD" ] ; then
     echo "Creating secret neoload with git credentials"
      "${K3SKUBECTL[@]}" -n "$NAMESPACE" create secret generic neoload --from-literal="SECRET_SCM_USER=$GIT_USER" --from-literal="SECRET_SCM_PASSWORD=$GIT_PASSWORD" --from-literal="NL_API_TOKEN=$NL_API_TOKEN"
    fi
  else
     echo "Creating secret neoload "
     "${K3SKUBECTL[@]}" -n "$NAMESPACE" create secret generic neoload --from-literal="NL_API_TOKEN=$NL_API_TOKEN"
  fi


   echo "Deploying neoload-service $NEOLOAD_SERVICE_VERSION"
   # to update the link
    curl -# -o distributor.yaml "https://raw.githubusercontent.com/keptn-contrib/neoload-service/$NEOLOAD_SERVICE_VERSION/config/neoloadexecutor/distributor.yaml"
    curl -# -o role.yaml "https://raw.githubusercontent.com/keptn-contrib/neoload-service/$NEOLOAD_SERVICE_VERSION/config/neoloadexecutor/role.yaml"

    if [[ "${DYNA}" == "true" ]]; then
      curl -# -o service.yaml "https://raw.githubusercontent.com/keptn-contrib/neoload-service/$NEOLOAD_SERVICE_VERSION/config/neoloadexecutor/service_withdynatrace.yaml"
    else
       curl -# -o service.yaml "https://raw.githubusercontent.com/keptn-contrib/neoload-service/$NEOLOAD_SERVICE_VERSION/config/neoloadexecutor/service.yaml"
    fi


    echo "Creating neoload configmap"
    "${K3SKUBECTL[@]}" -n "$NAMESPACE" create configmap neoload-config --from-literal="NL_WEB_HOST=$NL_WEB_HOST" --from-literal="NL_API_HOST=$NL_WEBAPI_HOST"  --from-literal="NL_WEB_ZONEID=$NL_ZONE_ID" --from-literal="NL_UPLOAD_HOST=$NL_WEBUPLOAD_HOST"


   #replace the namespace in the deployment
   sed -i "s/NAMESPACE_TO_REPLACE/$NAMESPACE/" service.yaml
   sed -i "s/NAMESPACE_TO_REPLACE/$NAMESPACE/" distributor.yaml
   sed -i "s/NAMESPACE_TO_REPLACE/$NAMESPACE/" role.yaml
  "${K3SKUBECTL[@]}" -n "$NAMESPACE" apply -f role.yaml
  "${K3SKUBECTL[@]}" -n "$NAMESPACE" apply -f service.yaml
  "${K3SKUBECTL[@]}" -n "$NAMESPACE" apply -f distributor.yaml

  echo "Deleting jmeter-service"
  "${K3SKUBECTL[@]}" delete deployment jmeter-service -n keptn
   PODS=$("${K3SKUBECTL[@]}" -n "$NAMESPACE" get pods --no-headers | awk '{print $1}' | grep jmeter-service | tr '\n' ' ')
   echo "Deleting pods $PODS "
  "${K3SKUBECTL[@]}" -n "$NAMESPACE" delete pods "$PODS"  --wait=true --ignore-not-found



}

function install_demo_dynatrace {
  write_progress "Installing Dynatrace Demo Projects"

  # ==============================================================================================
  # Demo 1: Create a quality-gate project called "dynatrace"
  # Setup based on https://github.com/keptn-contrib/dynatrace-sli-service/tree/master/dashboard
  # This project also enables the auto-synchronization capability as explained here: https://github.com/keptn-contrib/dynatrace-service#synchronizing-service-entities-detected-by-dynatrace
  # ==============================================================================================
  export KEPTN_ENDPOINT="${PREFIX}://${KEPTN_DOMAIN}"
  export KEPTN_INGRESS=${FQDN}
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_QG_PROJECT}"
  ./create-keptn-project-from-template.sh quality-gate-dynatrace ${OWNER_EMAIL} ${KEPTN_QG_PROJECT} ${GIT_SERVER} ${GIT_USER}

  echo "Run first Dynatrace Quality Gate"
  keptn trigger evaluation --project="${KEPTN_QG_PROJECT}" --stage="${KEPTN_QG_STAGE}" --service="${KEPTN_QG_SERVICE}" --timeframe=30m


  # ==============================================================================================
  # Demo 2: Performance as a Self-service Project
  # Creates a single stage project that will execute JMeter performance tests against any URL you give it
  # To get Keptn also send events to a Dynatrace Monitored Entity simply tag the entity with ${KEPTN_QG_STAGE}
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_PERFORMANCE_PROJECT}"
  ./create-keptn-project-from-template.sh performance-as-selfservice ${OWNER_EMAIL} ${KEPTN_PERFORMANCE_PROJECT} ${GIT_SERVER} ${GIT_USER}

  # ==============================================================================================
  # Demo 3: Auto-Remediation
  # Creates a single stage project with a service that will map to all incoming problem types, e.g: infrastructure, applcation ...
  # The service will have its own remediation.yaml to execute remediation scripts
  # This demo will leverage the generic-executor-service to execute bash or python scripts for remediation
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_REMEDIATION_PROJECT}"
  ./create-keptn-project-from-template.sh auto-remediation ${OWNER_EMAIL} ${KEPTN_REMEDIATION_PROJECT} ${GIT_SERVER} ${GIT_USER}

  # ==============================================================================================
  # Demo 4: Blue/Green Delivery with Istio
  # Creates a 3 stage delivery project to delivery the singlenode sample app in dev, staging and production
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_DELIVERY_PROJECT}"
  ./create-keptn-project-from-template.sh delivery-simplenode ${OWNER_EMAIL} ${KEPTN_DELIVERY_PROJECT} ${GIT_SERVER} ${GIT_USER}

  # ==============================================================================================
  # Demo 5: Canary Delivery with Argo Rollouts
  # Creates canary delivery project using Argo Rollouts
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_ROLLOUT_PROJECT}"
  ./create-keptn-project-from-template.sh delivery-rollout ${OWNER_EMAIL} ${KEPTN_ROLLOUT_PROJECT} ${GIT_SERVER} ${GIT_USER}

  # ==============================================================================================
  # Demo 6: Advanced Performance
  # Creates a project with 3 sequences of performance testing: functional, simple load, performance
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_ADV_PERFORMANCE_PROJECT}"
  ./create-keptn-project-from-template.sh advanced-performance ${OWNER_EMAIL} ${KEPTN_ADV_PERFORMANCE_PROJECT} ${GIT_SERVER} ${GIT_USER}

  # last step is to setup upstream gits
  if [[ "${GITEA}" == "true" ]]; then
    gitea_readApiTokenFromFile
    gitea_createKeptnRepo "${KEPTN_QG_PROJECT}"
    gitea_createKeptnRepo "${KEPTN_PERFORMANCE_PROJECT}"
    gitea_createKeptnRepo "${KEPTN_REMEDIATION_PROJECT}"
    gitea_createKeptnRepo "${KEPTN_DELIVERY_PROJECT}"
    gitea_createKeptnRepo "${KEPTN_ROLLOUT_PROJECT}"
    gitea_createKeptnRepo "${KEPTN_ADV_PERFORMANCE_PROJECT}"
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
6 Dynatrace Demo projects have been created, the Keptn CLI has been downloaded and configured and a first demo quality gate was already executed.

For the Quality Gate Use case you can do this::
1: Open the Keptn's Bridge for your Quality Gate Project: 
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_QG_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: Run another Quality Gate via: 
   keptn trigger evaluation --project=${KEPTN_QG_PROJECT} --stage=${KEPTN_QG_STAGE} --service=${KEPTN_QG_SERVICE}
3: Automatically synchronize your Dynatrace monitored services with Keptn by adding the 'keptn_managed' and 'keptn_service:SERVICENAME' tag
   More details here: https://github.com/keptn-contrib/dynatrace-service#synchronizing-service-entities-detected-by-dynatrace

For the Performance as a Self-Service Demo we have created a project that contains a simple JMeter test that can test a single URL.
Here are things you can do:
1: Open the Keptn's Bridge for your Performance Project:
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_PERFORMANCE_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: In Dynatrace pick a service you want to run a simple test against and add the manual label: ${KEPTN_PERFORMANCE_SERVICE}
3: (optional) Create an SLO-Dashboard in Dynatrace with the name: KQG;project=${KEPTN_PERFORMANCE_PROJECT};service=${KEPTN_PERFORMANCE_SERVICE};stage=${KEPTN_PERFORMANCE_STAGE}
4: Trigger a Performance test for an application that is accessible from this machine, e.g. http://yourapp/yoururl
   ./trigger.performance.testing.sh ${KEPTN_PERFORMANCE_PROJECT} ${KEPTN_PERFORMANCE_STAGE} ${KEPTN_PERFORMANCE_SERVICE} performance_withdtmint http://yourapp/yoururl
5: Watch data in Dynatrace as the test gets executed and watch the Quality Gate in Keptn after test execution is done!

For the Auto-Remediation Demo we have created project ${KEPTN_REMEDIATION_PROJECT} that contains a default remediation.yaml and some bash and python scripts
In order for this to work do
1: Create a new Problem Notification Integration as explained in the readme
2: Either force Dynatrace to open a problem ticket, create one through the API or execute ./dynatrace/createdtproblem.sh
3: Watch the auto-remediation actions in Keptn's bridge
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_REMEDIATION_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD

For the Delivery Use Case we have created project ${KEPTN_DELIVERY_PROJECT} that allows you to deliver a simplenode app in 3 stages (dev, staging, production)
To trigger a delivery simple do this
1: Trigger a delivery through the Keptn CLI
   keptn trigger delivery --project=${KEPTN_DELIVERY_PROJECT} --stage=${KEPTN_DELIVERY_STAGE_DEV} --service=${KEPTN_DELIVERY_SERVICE} --image=docker.io/grabnerandi/simplenodeservice --tag=1.0.0
2: Watch the delivery progress in Keptn's bridge
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_DELIVERY_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD

For the Canary Delivery Use Case we have created project ${KEPTN_ROLLOUT_PROJECT} that uses Argo Rollouts for production canary deployments
To trigger a delivery simple do this
1: Trigger a delivery through the Keptn API as explained in the readme
2: Watch the delivery progress in Keptn's bridge
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_DELIVERY_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD


For the Advanced Performance Use Use Case we have created project ${KEPTN_ADV_PERFORMANCE_PROJECT} that first runs functional then real performance tests
To trigger a delivery simple do this
1: Open the Keptn's Bridge for your Performance Project:
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_ADV_PERFORMANCE_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: In Dynatrace pick a service you want to run a simple test against and add the manual label: ${KEPTN_ADV_PERFORMANCE_SERVICE}
3: (optional) Create an SLO-Dashboard in Dynatrace with the name: KQG;project=${KEPTN_ADV_PERFORMANCE_PROJECT};service=${KEPTN_ADV_PERFORMANCE_SERVICE};stage=${KEPTN_ADV_PERFORMANCE_STAGE}
4: Trigger a Performance test for an application that is accessible from this machine, e.g. http://yourapp/yoururl
   ./trigger.performance.testing.sh ${KEPTN_ADV_PERFORMANCE_PROJECT} functional ${KEPTN_ADV_PERFORMANCE_SERVICE} performance http://yourapp/yoururl
5: Watch data in Dynatrace as the test gets executed and watch the Quality Gate in Keptn after test execution is done!


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
    --type)
        INSTALL_TYPE="${2}"
        shift 2
      ;;
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
        if [[ "$CERT_EMAIL" == "none" ]]; then
          if [[ "$OWNER_EMAIL" == "none" ]]; then
            echo "Enabling LetsEncrpyt Support requires you to set CERT_EMAIL"
            exit 1
          else 
            echo "As CERT_EMAIL is not set taking $OWNER_EMAIL for CERT_EMAIL"
            CERT_EMAIL="$OWNER_EMAIL"
          fi 
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
    --controlplane)
        echo "Installing Keptn Control Plane"
        KEPTN_TYPE="controlplane"
        KEPTN_DELIVERYPLANE="false"
        KEPTN_EXECUTIONPLANE="false"
        KEPTN_CONTROLPLANE="true"
        shift
        ;;
    --deliveryplane)
        echo "Installing Keptn Delivery Plane"
        KEPTN_TYPE="deliveryplane"
        KEPTN_DELIVERYPLANE="true"
        KEPTN_EXECUTIONPLANE="false"
        KEPTN_CONTROLPLANE="false"
        shift
        ;;
    --executionplane)
        echo "Installing Keptn Execution Plane"
        KEPTN_TYPE="executionplane"
        KEPTN_DELIVERYPLANE="false"
        KEPTN_EXECUTIONPLANE="true"
        KEPTN_CONTROLPLANE="false"

        # need keptn_endpoint, keptn_token and distributor filter project, stage & service
        if [[ "$KEPTN_CONTROL_PLANE_DOMAIN" == "" ]]; then
          echo "To install an execution plane set KEPTN_CONTROL_PLANE_DOMAIN to the HOSTNAME of the Keptn Control Plane, e.g: keptn.yourdomain.com"
          exit 1
        fi 
        if [[ "$KEPTN_CONTROL_PLANE_API_TOKEN" == "" ]]; then
          echo "To install an execution plane set KEPTN_CONTROL_PLANE_API_TOKEN to the API_TOKEN of your of the Keptn Control Plane"
          exit 1
        fi 

        echo "Here are the execution plane filters that will be used. If you want to change them set those env-variables before running the script"
        echo "KEPTN_EXECUTION_PLANE_STAGE_FILTER=${KEPTN_EXECUTION_PLANE_STAGE_FILTER}"
        echo "KEPTN_EXECUTION_PLANE_SERVICE_FILTER=${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}"
        echo "KEPTN_EXECUTION_PLANE_PROJECT_FILTER=${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
        
        shift
        ;;     
    --with-jmeter)
        echo "Enabling JMeter Support"
        JMETER="true"
        NEOLOAD="false"
        shift
        ;;
      --with-neoload)
        echo "Enabling NeoLoad Support"
        JMETER="false"
        NEOLOAD="true"
         if [[ "$NL_API_TOKEN" == "none" ]]; then
          echo "You have to set NL_API_TOKEN to a Token"
          exit 1
        fi
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
        if [[ "$DT_PAAS_TOKEN" == "none" ]]; then
          echo "You have to set DT_PAAS_TOKEN to a PAAS Token that will be used to deploy the Dynatrace OneAgent on the k3s cluster"
          echo "Without that you wont have any monitoring of that cluster which will prohibit some of the dynatrace demos"
          echo "If you want to learn more please visit https://www.dynatrace.com/support/help/technology-support/cloud-platforms/kubernetes/deploy-oneagent-k8/"
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

        if [[ $DEMO == "dynatrace" ]]; then 
          if [[ $OWNER_EMAIL == "none" ]]; then 
            echo "For installing the Dynatrace demo you need to export OWNER_EMAIL to a valid email of a Dynatrace User Account. The demo will create dashboards using that owner!"
            exit 1
          fi 
        fi

        # need to make sure we install the generic exector service for our demo as well as jmeter
        GENERICEXEC="true"


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
    echo 'Install it e.g: brew install jp or sudo apt-get install jq'
    exit 1
  fi
  if ! [ -x "$(command -v yq)" ]; then
    echo 'Error: yq is not installed.' >&2
    echo 'Install it e.g: brew install yq or sudo apt-get install yq'
    exit 1
  fi  
  if ! [ -x "$(command -v curl)" ]; then
    echo 'Error: curl is not installed.' >&2
    echo 'Install it e.g: brew install curl or sudo apt-get install curl'
    exit 1
  fi

  get_ip
  get_fqdn
  get_kubectl

  if [[ "${INSTALL_TYPE}" == "all" ]]; then
    get_helm
    get_k3s
    get_oneagent    
    check_k8s
    install_certmanager
    install_keptn
    install_keptncli
    install_demo  
    print_config
  fi

  if [[ "${INSTALL_TYPE}" == "k3s" ]]; then
    get_helm
    get_k3s
    get_oneagent    
    check_k8s
    install_certmanager
  fi

  if [[ "${INSTALL_TYPE}" == "keptn" ]]; then
    install_keptn
    install_keptncli
  fi

  if [[ "${INSTALL_TYPE}" == "demo" ]]; then
    install_demo
  fi

  if [[ "${INSTALL_TYPE}" == "gitus" ]]; then
    gitea_readApiTokenFromFile
    gitea_createKeptnRepos
  fi

}

main "${@}"
