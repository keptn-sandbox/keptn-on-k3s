#!/usr/bin/env bash

set -eu

# Keptn Version Information
KEPTNVERSION=${KEPTNVERSION:-0.17.0}
KEPTN_TYPE="controlplane"
KEPTN_DELIVERYPLANE=false
KEPTN_EXECUTIONPLANE=false
KEPTN_CONTROLPLANE=true

DISABLE_BRIDGE_AUTH="false"

ISTIO_VERSION="1.9.1"
INGRESS_PORT="80"
INGRESS_PROTOCOL="http"
ISTIO_GATEWAY="public-gateway.istio-system"

ARGO_ROLLOUTS_VERSION="v1.2.1"
ARGO_ROLLOUTS_EXTENSION_VERSION="latest"

# For execution plane these are the env-variables that identify the keptn control plane
KEPTN_CONTROL_PLANE_DOMAIN=${KEPTN_CONTROL_PLANE_DOMAIN:-none}
KEPTN_CONTROL_PLANE_API_TOKEN=${KEPTN_CONTROL_PLANE_API_TOKEN:-none}

# in demo installations its likely that control plane doesnt have a valid SSL - so - we default to validate SSL false
KEPTN_CONTROL_PLANE_SSL_VERIFY=${KEPTN_CONTROL_PLANE_SSL_VERIFY:-false}
if [[ $KEPTN_CONTROL_PLANE_DOMAIN == *"live.dynatrace.com" ]]; then 
  # unless we connect to a dynatrace cloud automation tenant - we default to true
  KEPTN_CONTROL_PLANE_SSL_VERIFY="true"
fi 

# For execution plane here are the filters
KEPTN_EXECUTION_PLANE_STAGE_FILTER=${KEPTN_EXECUTION_PLANE_STAGE_FILTER:-""}
KEPTN_EXECUTION_PLANE_SERVICE_FILTER=${KEPTN_EXECUTION_PLANE_SERVICE_FILTER:-""}
KEPTN_EXECUTION_PLANE_PROJECT_FILTER=${KEPTN_EXECUTION_PLANE_PROJECT_FILTER:-""}

# PROM_SERVICE_VERSION="release-0.6.1"
# # PROM_SLI_SERVICE_VERSION="release-0.3.0" <<-- has been merged with the prometheus service
DT_SERVICE_VERSION="0.23.0"
# DT_SLI_SERVICE_VERSION="release-0.12.0" <<-- has been merged with dynatrace-service!
JOBEEXECUTOR_SERVICE_VERSION="0.2.3"
# GENERICEXEC_SERVICE_VERSION="release-0.8.4"
MONACO_SERVICE_VERSION="release-0.9.1"  # migratetokeptn08
ARGO_SERVICE_VERSION="0.9.4"
LOCUST_SERVICE_VERSION="release-0.1.5"
GITEA_PROVISIONER_VERSION="0.1.1"

# Dynatrace Credentials
DT_TENANT=${DT_TENANT:-none}
DT_API_TOKEN=${DT_API_TOKEN:-none}
DT_OPERATOR_TOKEN=${DT_OPERATOR_TOKEN:-none}
DT_INGEST_TOKEN=${DT_INGEST_TOKEN:-none}
OWNER_EMAIL=${OWNER_EMAIL:-none}

# Install Flags
PROVIDER="none"
ISTIO=${ISTIO:-false}
MY_IP="none"
FQDN="none"
KEPTN_DOMAIN="none"
PREFIX="https"
CERTS="selfsigned"
CERT_EMAIL=${CERT_EMAIL:-none}
LE_STAGE=${LE_STAGE:-none}
XIP="false" 
NIP="false"
INSTALL_TYPE="all"  # "k3s", "keptn", "demo", "gitea"

PROM="false"
DYNA="false"
MONACO="false"
GITEA="false"
JMETER="false"
LOCUST="false"
SLACK="false"
GENERICEXEC="false"
JOBEXECUTOR="false"

GITEA_VERSION="v2.2.0"

DEMO="false"


# Keptn Credentials
KEPTN_API_TOKEN="$(head -c 16 /dev/urandom | base64)"
BRIDGE_PASSWORD="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

# k8s config
K3SVERSION="v1.22"
BINDIR="/usr/local/bin"
K3SKUBECTL=("${BINDIR}/k3s" "kubectl")
KUBECONFIG=/etc/rancher/k3s/k3s.yaml


#Gitea - default values
GIT_USER=${GIT_USER:-keptn}
GIT_PASSWORD=${GIT_SERVER:-keptn#R0cks}
GIT_SERVER=${GIT_SERVER:-none}
GIT_DOMAIN=${GIT_DOMAIN:-none}

# static vars
GIT_TOKEN="keptn-upstream-token"
TOKEN_FILE=$GIT_TOKEN.json

# keptn demo project defaults
TEMPLATE_DIRECTORY="keptn_project_templates"

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
KEPTN_ROLLOUT_STAGE_STAGING="staging"
KEPTN_ROLLOUT_SERVICE="simplenode"

KEPTN_TWOSTAGE_DELIVERY_PROJECT="demo-twostage-delivery"
KEPTN_TWOSTAGE_DELIVERY_STAGE_STAGING="staging"
KEPTN_TWOSTAGE_DELIVERY_STAGE_PRODUCTION="production"
KEPTN_TWOSTAGE_DELIVERY_SERVICE="simplenode"

KEPTN_ADV_PERFORMANCE_PROJECT="demo-adv-performance"
KEPTN_ADV_PERFORMANCE_STAGE="performance"
KEPTN_ADV_PERFORMANCE_SERVICE="appundertest"

KEPTN_PROMETHEUS_QG_PROJECT="prometheus-qg"
KEPTN_PROMETHEUS_QG_STAGE="quality-gate"
KEPTN_PROMETHEUS_QG_SERVICE="helloservice"

KEPTN_GENERIC_AUTOMATION_PROJECT="generic-automation"

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

  if [[ "${KEPTN_CONTROL_PLANE_API_TOKEN}" == "none" ]]; then 
    echo "$(${K3SKUBECTL[@]} get secret keptn-api-token -n keptn -o jsonpath={.data.keptn-api-token} | base64 -d)"
  else
    echo "${KEPTN_CONTROL_PLANE_API_TOKEN}"
  fi
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

function get_nip_address {
  address="${1:-none}"
  if [[ $address != none ]]; then
    echo "${address}.nip.io"
  else
    echo "No address given"
    exit 1
  fi
}

function get_fqdn {
  if [[ "$FQDN" == "none" ]]; then

    FQDN="${MY_IP}"

    if [[ "${LE_STAGE}" == "staging" ]] || [[ "${NIP}" == "true" ]]; then
      FQDN="$(get_nip_address "${MY_IP}")"
    fi
    if [[ "${LE_STAGE}" == "production" ]]; then
      echo "Issuing Production LetsEncrypt Certificates with nip.io as domain is not possible"
      exit 1
    fi
  fi

  KEPTN_DOMAIN="keptn.${FQDN}"

  # if GIT_DOMAIN wasnt set and we will install GITEA lets create the domain name
  if [[ "${GIT_DOMAIN}" == "none" ]] && [[ "${GITEA}" == "true" ]]; then
    GIT_DOMAIN="git.${FQDN}"
    # always acceses git via http as we otherwise may have problem with self-signed certificate!
    GIT_SERVER="http://$GIT_DOMAIN"
  fi
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

  # wait for nginx to be ready

}

# Installs Dynatrace OneAgent Operator on the k3s cluster
function get_oneagent {
  # only install if all dynatrace settings are specified
  if [[ "$DT_TENANT" == "none" ]] || [[ "$DT_OPERATOR_TOKEN" == "none" ]] ||[[ "$DT_INGEST_TOKEN" == "none" ]]; then 
    write_progress "WARNING - NOT INSTALLING Dynatrace OneAgent Operator for k3s because relevant tokens (DT_OPERATOR_TOKEN & DT_INGEST_TOKEN) not specified!"
    return; 
  fi

  write_progress "Installing Dynatrace OneAgent Operator for k3s"

  "${K3SKUBECTL[@]}" create namespace dynatrace
  "${K3SKUBECTL[@]}" apply -f https://github.com/Dynatrace/dynatrace-operator/releases/download/v0.6.0/kubernetes.yaml
  "${K3SKUBECTL[@]}" -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook --timeout=300s
  
  sed -e 's~DT_TENANT~'"$DT_TENANT"'~' \
    -e 's~DT_OPERATOR_TOKEN~'"$DT_OPERATOR_TOKEN"'~' \
    -e 's~DT_INGEST_TOKEN~'"$DT_INGEST_TOKEN"'~' \
    -e 's~DT_HOST_GROUP~'"$KEPTN_TYPE"'~' \
    -e 's~KEPTN_TYPE~'"$KEPTN_TYPE"'~' \
    -e 's~KEPTN_STAGE~'"$KEPTN_EXECUTION_PLANE_STAGE_FILTER"'~' \
    ./files/dynatrace/dynakube_06.yaml > dynakube_06_tmp.yaml
  
  
  "${K3SKUBECTL[@]}" apply -f dynakube_06_tmp.yaml
  rm dynakube_06_tmp.yaml


#  helm repo add dynatrace https://raw.githubusercontent.com/Dynatrace/helm-charts/master/repos/stable
#  "${K3SKUBECTL[@]}" create namespace dynatrace

#  kubectl apply -f https://github.com/Dynatrace/dynatrace-oneagent-operator/releases/latest/download/dynatrace.com_oneagents.yaml 
#  kubectl apply -f https://github.com/Dynatrace/dynatrace-oneagent-operator/releases/latest/download/dynatrace.com_oneagentapms.yaml

#  sed -e 's~DT_TENANT~'"$DT_TENANT"'~' \
#    -e 's~DT_API_TOKEN~'"$DT_API_TOKEN"'~' \
#    -e 's~DT_INGEST_TOKEN~'"$DT_INGEST_TOKEN"'~' \
#    -e 's~DT_HOST_GROUP~'"$KEPTN_TYPE"'~' \
#    -e 's~KEPTN_TYPE~'"$KEPTN_TYPE"'~' \
#    -e 's~KEPTN_STAGE~'"$KEPTN_EXECUTION_PLANE_STAGE_FILTER"'~' \
#    ./files/dynatrace/oneagent_values.yaml > oneagent_values.yaml

#  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
#  helm install dynatrace-oneagent-operator \
#    dynatrace/dynatrace-oneagent-operator -n\
#    dynatrace --values oneagent_values.yaml

  # TODO -once ActiveGate supports local k8s API -> Install OneAgent Operator & Active Gate instead of just OneAgent Operator
  # export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  # wget https://github.com/dynatrace/dynatrace-operator/releases/latest/download/install.sh -O install.sh && sh ./install.sh --api-url "https://$DT_TENANT/api" --api-token "${DT_API_TOKEN}" --paas-token "${DT_INGEST_TOKEN}" --enable-k8s-monitoring --cluster-name "keptn-on-k3s-${FQDN}"

#  rm oneagent_values.yaml
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
  kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}/install.yaml
  # "${K3SKUBECTL[@]}" apply -n argo-rollouts -f https://raw.githubusercontent.com/argoproj/argo-rollouts/${ARGO_ROLLOUTS_VERSION}/manifests/install.yaml

  # now also installing the argo rollout extension for kubectl
  curl -LO https://github.com/argoproj/argo-rollouts/releases/${ARGO_ROLLOUTS_EXTENSION_VERSION}/download/kubectl-argo-rollouts-linux-amd64
  sudo chmod +x ./kubectl-argo-rollouts-linux-amd64
  sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
}

function get_istio {

  if [[ "$ISTIO" == "false" ]]; then
    echo "Not installing istio as ISTIO=false"
    return
  fi 

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

  # Create ConfigMap Entry for keptn's helm service
  "${K3SKUBECTL[@]}" create configmap -n keptn ingress-config \
      --from-literal=ingress_hostname_suffix=${FQDN} \
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

  echo "k8s - Waiting for all system pods to be ready - 1st attempt (max 60s)"
  "${K3SKUBECTL[@]}" wait --namespace=default --for=condition=Ready pods --timeout=60s --all
}

function disable_bridge_auth {
  ${K3SKUBECTL[@]} -n keptn delete secret bridge-credentials
  ${K3SKUBECTL[@]} -n keptn delete pods --selector=app.kubernetes.io/name=bridge
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
      --repo="https://charts.keptn.sh" \
      --set continuous-delivery.enabled=false \
      --kubeconfig="$KUBECONFIG"
#      --set bridge.installationType="QUALITY_GATES,CONTINUOUS_OPERATIONS,CONTINUOUS_DELIVERY" \
  fi 

  if [[ "${KEPTN_DELIVERYPLANE}" == "true" ]]; then
    write_progress "Installing Keptn for Continuous Delivery (Control & Execution Plane)"
    helm upgrade keptn keptn --install --wait \
      --version="${KEPTNVERSION}" \
      --create-namespace --namespace=keptn \
      --repo="https://charts.keptn.sh" \
      --set continuous-delivery.enabled=true \
      --kubeconfig="$KUBECONFIG"
#      --set bridge.installationType="QUALITY_GATES,CONTINUOUS_OPERATIONS,CONTINUOUS_DELIVERY" \

    # no need to additionally install jmeter as we install a delivery plane anyway!
    JMETER="false"

    # need to install Istio for Delivery Plane as we are potentially depoying sevices blue / green
    get_istio
    get_argorollouts

    # Since Keptn 0.8.2 the Helm Service and JMeter Service are no longer installed through the Keptn Helm Chart. so - installing them now
    # Install JMeter if requested
    if [[ "${JMETER}" == "true" ]]; then
      helm install jmeter-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/jmeter-service-${KEPTNVERSION}.tgz -n keptn
    fi
    # ALWAYS install Helm-Service on Delivery-Plane
    helm install helm-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/helm-service-${KEPTNVERSION}.tgz -n keptn

    # ALWAYS Install the Argo Service as this is needed for one of the demo use cases
    helm install argo-service -n keptn https://github.com/keptn-contrib/argo-service/releases/download/${ARGO_SERVICE_VERSION}/argo-service-${ARGO_SERVICE_VERSION}.tgz

    # Install Locust if requested
    if [[ "${LOCUST}" == "true" ]]; then
      apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/locust-service/${LOCUST_SERVICE_VERSION}/deploy/service.yaml"

      # For KNOWN ISSUE in Keptn 0.14.1
      "${K3SKUBECTL[@]}" -n keptn set env deployment/locust-service --containers=distributor PUBSUB_URL="nats://keptn-nats"
    fi 
  fi

  if [[ "${KEPTN_EXECUTIONPLANE}" == "true" ]]; then
    # following instructions from https://keptn.sh/docs/0.8.x/operate/multi_cluster/#install-keptn-execution-plane
    write_progress "Installing Keptn Execution Plane to connect to ${KEPTN_CONTROL_PLANE_DOMAIN}"

    # lets make sure the keptn namespace is created
    create_namespace "keptn"

    # need to install Istio for Execution Plane as we potentially deliver services with Blue / Green
    # Create an empty ingress-config configmap as it will be replaced by get_istio. Normally this config map gets created during the keptn install
    "${K3SKUBECTL[@]}" -n keptn create configmap ingress-config 
    get_istio
    get_argorollouts

    # Install the Helm Service - and increase memory and cpu limits
    curl -fsSL -o /tmp/helm.values.yaml https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/helm-service/chart/values.yaml
    yq w -i /tmp/helm.values.yaml "remoteControlPlane.enabled" "true"
    yq w -i /tmp/helm.values.yaml "remoteControlPlane.api.hostname" "${KEPTN_CONTROL_PLANE_DOMAIN}"
    yq w -i /tmp/helm.values.yaml "remoteControlPlane.api.token" "${KEPTN_CONTROL_PLANE_API_TOKEN}"
    yq w -i /tmp/helm.values.yaml "distributor.projectFilter" "${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
    yq w -i /tmp/helm.values.yaml "distributor.stageFilter" "${KEPTN_EXECUTION_PLANE_STAGE_FILTER}"
    yq w -i /tmp/helm.values.yaml "distributor.serviceFilter" "${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}"
    yq w -i /tmp/helm.values.yaml "remoteControlPlane.api.apiValidateTls" "${KEPTN_CONTROL_PLANE_SSL_VERIFY}"
    yq w -i /tmp/helm.values.yaml "resources.requests.cpu" "50m"
    yq w -i /tmp/helm.values.yaml "resources.requests.memory" "128Mi"
    yq w -i /tmp/helm.values.yaml "resources.limits.cpu" "200m"
    yq w -i /tmp/helm.values.yaml "resources.limits.memory" "512Mi"
    
    helm install helm-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/helm-service-${KEPTNVERSION}.tgz -n keptn --create-namespace --values=/tmp/helm.values.yaml

    # Install the Argo Service for just the demo-rollout project
    helm install argo-service -n keptn https://github.com/keptn-contrib/argo-service/releases/download/${ARGO_SERVICE_VERSION}/argo-service-${ARGO_SERVICE_VERSION}.tgz
    "${K3SKUBECTL[@]}" -n keptn set env deployment/argo-service --containers=distributor PROJECT_FILTER="demo-rollout"
    "${K3SKUBECTL[@]}" -n keptn set env deployment/argo-service --containers=distributor STAGE_FILTER="${KEPTN_EXECUTION_PLANE_STAGE_FILTER}" SERVICE_FILTER="${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}" PROJECT_FILTER="${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
    "${K3SKUBECTL[@]}" -n keptn set env deployment/argo-service --containers=distributor KEPTN_API_ENDPOINT="https://${KEPTN_CONTROL_PLANE_DOMAIN}/api" KEPTN_API_TOKEN="${KEPTN_CONTROL_PLANE_API_TOKEN}" HTTP_SSL_VERIFY="${KEPTN_CONTROL_PLANE_SSL_VERIFY}"

    # Install JMeter if the user wants to
    if [[ "${JMETER}" == "true" ]]; then
      curl -fsSL -o /tmp/jmeter.values.yaml https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/jmeter-service/chart/values.yaml
      yq w -i /tmp/jmeter.values.yaml "remoteControlPlane.enabled" "true"
      yq w -i /tmp/jmeter.values.yaml "remoteControlPlane.api.hostname" "${KEPTN_CONTROL_PLANE_DOMAIN}"
      yq w -i /tmp/jmeter.values.yaml "remoteControlPlane.api.token" "${KEPTN_CONTROL_PLANE_API_TOKEN}"
      yq w -i /tmp/jmeter.values.yaml "distributor.projectFilter" "${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
      yq w -i /tmp/jmeter.values.yaml "distributor.stageFilter" "${KEPTN_EXECUTION_PLANE_STAGE_FILTER}"
      yq w -i /tmp/jmeter.values.yaml "distributor.serviceFilter" "${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}"
      yq w -i /tmp/jmeter.values.yaml "remoteControlPlane.api.apiValidateTls" "${KEPTN_CONTROL_PLANE_SSL_VERIFY}"

      helm install jmeter-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/jmeter-service-${KEPTNVERSION}.tgz -n keptn --create-namespace --values=/tmp/jmeter.values.yaml

      # no need to additionally install jmeter afterwards as we install it as part of the execution plane anyway!
      JMETER="false"
    fi

    if [[ "${GENERICEXEC}" == "true" ]]; then
      write_progress "NO LONGER SUPPORTING GENERIC EXECUTOR. PLEASE USE JOB EXECUTOR"

      GENERICEXEC="false"
    fi

    if [[ "${JOBEXECUTOR}" == "true" ]]; then
      write_progress "Installing Job Executor Service on the Execution Plane"

      TASK_SUBSCRIPTION="sh.keptn.event.deployment.triggered,sh.keptn.event.test.triggered,sh.keptn.event.evaluation.triggered,sh.keptn.event.rollback.triggered,sh.keptn.event.release.triggered,sh.keptn.event.action.triggered,sh.keptn.event.getjoke.triggered,sh.keptn.event.validate.triggered"

      helm upgrade --install --create-namespace -n keptn \
        job-executor-service https://github.com/keptn-contrib/job-executor-service/releases/download/${JOBEEXECUTOR_SERVICE_VERSION}/job-executor-service-${JOBEEXECUTOR_SERVICE_VERSION}.tgz \
        --set remoteControlPlane.enabled=true \
        --set remoteControlPlane.topicSubscription='${TASK_SUBSCRIPTION}' \
        --set remoteControlPlane.api.protocol=https \
        --set remoteControlPlane.api.hostname=${KEPTN_CONTROL_PLANE_DOMAIN} \
        --set remoteControlPlane.api.token=${KEPTN_CONTROL_PLANE_API_TOKEN}

     " JOBEXECUTOR="false""
    fi


    if [[ "${MONACO}" == "true" ]]; then
      write_progress "Installing Monaco (Monitoring as Code) on Execution Plane"
      apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/monaco-service/${MONACO_SERVICE_VERSION}/deploy/service.yaml"
      "${K3SKUBECTL[@]}" -n keptn set env deployment/monaco-service --containers=monaco-service CONFIGURATION_SERVICE="http://localhost:8081/configuration-service"
      "${K3SKUBECTL[@]}" -n keptn set env deployment/monaco-service --containers=distributor STAGE_FILTER="${KEPTN_EXECUTION_PLANE_STAGE_FILTER}" SERVICE_FILTER="${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}" PROJECT_FILTER="${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
      "${K3SKUBECTL[@]}" -n keptn set env deployment/monaco-service --containers=distributor KEPTN_API_ENDPOINT="https://${KEPTN_CONTROL_PLANE_DOMAIN}/api" KEPTN_API_TOKEN="${KEPTN_CONTROL_PLANE_API_TOKEN}" HTTP_SSL_VERIFY="${KEPTN_CONTROL_PLANE_SSL_VERIFY}"
    fi 

    # Install Locust if the user wants to
    if [[ "${LOCUST}" == "true" ]]; then
      apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/locust-service/${LOCUST_SERVICE_VERSION}/deploy/service.yaml"
      "${K3SKUBECTL[@]}" -n keptn set env deployment/locust-service --containers=locust-service CONFIGURATION_SERVICE="http://localhost:8081/configuration-service"
      "${K3SKUBECTL[@]}" -n keptn set env deployment/locust-service --containers=distributor STAGE_FILTER="${KEPTN_EXECUTION_PLANE_STAGE_FILTER}" SERVICE_FILTER="${KEPTN_EXECUTION_PLANE_SERVICE_FILTER}" PROJECT_FILTER="${KEPTN_EXECUTION_PLANE_PROJECT_FILTER}"
      "${K3SKUBECTL[@]}" -n keptn set env deployment/locust-service --containers=distributor KEPTN_API_ENDPOINT="https://${KEPTN_CONTROL_PLANE_DOMAIN}/api" KEPTN_API_TOKEN="${KEPTN_CONTROL_PLANE_API_TOKEN}" HTTP_SSL_VERIFY="${KEPTN_CONTROL_PLANE_SSL_VERIFY}"
    fi

  fi
 
  if [[ "${PROM}" == "true" ]]; then
     write_progress "Installing Prometheus"
     helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
     "${K3SKUBECTL[@]}" create ns prometheus
     helm install prometheus prometheus-community/prometheus --namespace prometheus

     write_progress "Installing Prometheus Service"

     "${K3SKUBECTL[@]}" apply -f "https://raw.githubusercontent.com/keptn-contrib/prometheus-service/${PROM_SERVICE_VERSION}/deploy/role.yaml" -n prometheus
     apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/prometheus-service/${PROM_SERVICE_VERSION}/deploy/service.yaml"

     "${K3SKUBECTL[@]}" set env deploy/prometheus-service --containers=prometheus-service PROMETHEUS_NS=prometheus ALERT_MANAGER_NS=prometheus -n keptn
  fi

  # Install Dynatrace Services
  if [[ "${DYNA}" == "true" ]]; then

    if [[ "${KEPTN_CONTROLPLANE}" == "true" ]] || [[ "${KEPTN_DELIVERYPLANE}" == "true" ]]; then
      write_progress "Installing Dynatrace SLI Services on Control / Delivery Plane"

      # Installing core dynatrace services
      helm upgrade --install dynatrace-service -n keptn https://github.com/keptn-contrib/dynatrace-service/releases/download/${DT_SERVICE_VERSION}/dynatrace-service-${DT_SERVICE_VERSION}.tgz --set dynatraceService.config.keptnApiUrl=${PREFIX}://${KEPTN_DOMAIN}/api --set dynatraceService.config.keptnBridgeUrl=${PREFIX}://${KEPTN_DOMAIN}/bridge

      # For KNOWN ISSUE in Keptn 0.14.1 - set the PUBSUB_URL
      "${K3SKUBECTL[@]}" -n keptn set env deployment/dynatrace-service --containers=distributor PUBSUB_URL="nats://keptn-nats"

      # lets make Dynatrace the default SLI provider (feature enabled with lighthouse 0.7.2)
      "${K3SKUBECTL[@]}" create configmap lighthouse-config -n keptn --from-literal=sli-provider=dynatrace || true 
    fi 
  fi 

  # Install Monaco Service
  if [[ "${MONACO}" == "true" ]]; then
    if [[ "${KEPTN_DELIVERYPLANE}" == "true" ]] ; then
      # Installing monaco service on deliveryplane
      write_progress "Installing Monaco (Monitoring as Code) on Delivery Plane"
      apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/monaco-service/${MONACO_SERVICE_VERSION}/deploy/service.yaml"

      # For KNOWN ISSUE in Keptn 0.14.1 - set the PUBSUB_URL
      "${K3SKUBECTL[@]}" -n keptn set env deployment/monaco-service --containers=distributor PUBSUB_URL="nats://keptn-nats"

    fi 
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
    helm install gitea gitea-charts/gitea --version "${GITEA_VERSION}" -f helm-gitea_gen.yaml --namespace git --kubeconfig="${KUBECONFIG}"
    rm helm-gitea_gen.yaml
    
    write_progress "Configuring Gitea Ingress Object (${GIT_DOMAIN})"
    sed -e 's~domain.placeholder~'"$GIT_DOMAIN"'~' \
        -e 's~issuer.placeholder~'"$CERTS"'~' \
        ./files/gitea/gitea-ingress.yaml > gitea-ingress_gen.yaml
    "${K3SKUBECTL[@]}" apply -n git -f gitea-ingress_gen.yaml
    rm gitea-ingress_gen.yaml    

    write_progress "Waiting for Gitea pods to be ready (max 5 minutes)"
    "${K3SKUBECTL[@]}" wait --namespace=git --for=condition=Ready pods --timeout=300s --all    

    # Installing Keptn Gitea Provisioner Service
    write_progress "Install Keptn Gitea Provisioner Service"
    helm install keptn-gitea-provisioner-service --namespace keptn https://github.com/keptn-sandbox/keptn-gitea-provisioner-service/releases/download/${GITEA_PROVISIONER_VERSION}/keptn-gitea-provisioner-service-${GITEA_PROVISIONER_VERSION}.tgz --kubeconfig="${KUBECONFIG}" \
      --set gitea.admin.create=true \
      --set gitea.admin.username=${GIT_USER} \
      --set gitea.admin.password=${GIT_PASSWORD} \
      --set gitea.endpoint=\"http://${GIT_DOMAIN}\" \
      --wait    

    "${K3SKUBECTL[@]}" set env -n keptn deployment/shipyard-controller --containers=shipyard-controller AUTOMATIC_PROVISIONING_URL="http://keptn-gitea-provisioner-service.keptn"
  fi

  if [[ "${GENERICEXEC}" == "true" ]]; then
    write_progress "NO LONGER SUPPORTING GENERIC EXECUTOR. PLEASE USE JOB EXECUTOR"
  fi


  if [[ "${JOBEXECUTOR}" == "true" ]]; then
      write_progress "Installing Job Executor Service"

      TASK_SUBSCRIPTION="sh.keptn.event.deployment.triggered,sh.keptn.event.test.triggered,sh.keptn.event.evaluation.triggered,sh.keptn.event.rollback.triggered,sh.keptn.event.release.triggered,sh.keptn.event.action.triggered,sh.keptn.event.getjoke.triggered,sh.keptn.event.validate.triggered"

      helm upgrade --install --create-namespace -n keptn \
        job-executor-service https://github.com/keptn-contrib/job-executor-service/releases/download/${JOBEEXECUTOR_SERVICE_VERSION}/job-executor-service-${JOBEEXECUTOR_SERVICE_VERSION}.tgz \
        --set remoteControlPlane.autoDetect.enabled=true \
        --set remoteControlPlane.topicSubscription='${TASK_SUBSCRIPTION}' \
        --set remoteControlPlane.api.token="" \
        --set remoteControlPlane.api.hostname="" \
        --set remoteControlPlane.api.protocol=""

      # For KNOWN ISSUE in Keptn 0.14.1
      # "${K3SKUBECTL[@]}" -n keptn set env deployment/job-executor-service --containers=distributor PUBSUB_URL="nats://keptn-nats"

      JOBEXECUTOR="false"
    fi

  if [[ "${SLACK}" == "true" ]]; then
    write_progress "NO LONGER INSTALLING SLACK SERVICE - PLEASE USE THE WEBHOOK INTEGRATION INSTEAD"
  fi

  # Installing JMeter Service on the control plane if requested!
  if [[ "${JMETER}" == "true" ]]; then
    write_progress "Installing JMeter Service"
    helm install jmeter-service https://github.com/keptn/keptn/releases/download/${KEPTNVERSION}/jmeter-service-${KEPTNVERSION}.tgz -n keptn --create-namespace

    # For KNOWN ISSUE in Keptn 0.14.1
    "${K3SKUBECTL[@]}" -n keptn set env deployment/jmeter-service --containers=distributor PUBSUB_URL="nats://keptn-nats"
  fi

  if [[ "${DISABLE_BRIDGE_AUTH}" == "true" ]]; then
    disable_bridge_auth
  fi

  write_progress "Waiting for Keptn pods to be ready (max 5 minutes)"
  sleep 30
  "${K3SKUBECTL[@]}" wait --namespace=keptn --for=condition=Ready pods --timeout=60s --all || true

  # Keptn Ingress only makes sense if we actually installed the keptn control or delivery plane
  if [[ "${KEPTN_DELIVERYPLANE}" == "true" ]] || [[ "${KEPTN_CONTROLPLANE}" == "true" ]]; then
    write_progress "Configuring Keptn Ingress Object (${KEPTN_DOMAIN})"
    sed -e 's~domain.placeholder~'"$KEPTN_DOMAIN"'~' \
      -e 's~issuer.placeholder~'"$CERTS"'~' \
      ./files/keptn/keptn-ingress.yaml > keptn-ingress_gen.yaml
    "${K3SKUBECTL[@]}" apply -n keptn -f keptn-ingress_gen.yaml
    rm keptn-ingress_gen.yaml

    write_progress "Waiting for certificates to be ready (max 5 minutes)"
    "${K3SKUBECTL[@]}" wait --namespace=keptn --for=condition=Ready certificate keptn-tls --timeout=300s
  fi 

  # For Dynatrace or Monaco create the secret. Has to be at the end as keptn_create_dynatrace_secret calls the Keptn API
  if [[ "${DYNA}" == "true" ]] || [[ "${MONACO}" == "true" ]]; then
    write_progress "Creating Dynatrace Secret!"

    # Always create the secret in Keptn as a secret
    keptn_create_dynatrace_secret 

    # As of today (Keptn 0.8.4) we also have to create the secret as a k8s secret on the execution plane as keptn secrets are not yet propagated!
    if [[ "${KEPTN_EXECUTIONPLANE}" == "true" ]]; then
      check_delete_secret dynatrace
    "${K3SKUBECTL[@]}" create secret generic -n keptn dynatrace \
      --from-literal="DT_TENANT=$DT_TENANT" \
      --from-literal="DT_API_TOKEN=$DT_API_TOKEN"
    fi 
  fi 

}

function get_keptncredentials {
  # If we are on the execution plane we can connect the keptn CLI to the Control Plane
  if [[ "${KEPTN_EXECUTIONPLANE}" == "true" ]]; then
    KEPTN_DOMAIN="${KEPTN_CONTROL_PLANE_DOMAIN}"
    KEPTN_API_TOKEN="${KEPTN_CONTROL_PLANE_API_TOKEN}"
  else
    KEPTN_API_TOKEN="$(get_keptn_token)"
  fi
}

function install_keptncli {

  echo "Installing the Keptn CLI"
  curl -sL https://get.keptn.sh | KEPTN_VERSION=${KEPTNVERSION} sudo -E bash

  get_keptncredentials
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
        gitea_createKeptnRepo $project || true
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

function check_dynatrace_credentials {
  echo "Enabling Dynatrace or Monaco Support: Requires you to set DT_TENANT, DT_API_TOKEN"
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
  if [[ "$DYNA" == "true" ]] && [[ "$DT_INGEST_TOKEN" == "none" ]]; then
    echo "You have to set DT_INGEST_TOKEN to a PAAS Token that will be used to deploy the Dynatrace OneAgent on the k3s cluster"
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
}

#
# Creates a Keptn Secret including DT_API_TOKEN AND DT_TENANT as name/value pairs
# 1. secret_name (optional). Default is dynatrace
# 2. scope (optional). Default is dynatrace-service
#
function keptn_create_dynatrace_secret {
  secret_name="${1:-dynatrace}"
  scope="${2:-dynatrace-service}"

  get_keptncredentials

  # CREATE Keptn Secret
  echo "Calling HTTP POST ${PREFIX}://${KEPTN_DOMAIN}/api/secrets/v1/secret"
  curl -k -X POST "${PREFIX}://${KEPTN_DOMAIN}/api/secrets/v1/secret" -H "accept: application/json" -H "x-token: ${KEPTN_API_TOKEN}" -H "Content-Type: application/json" -d "{ \"data\": { \"DT_TENANT\": \"${DT_TENANT}\", \"DT_API_TOKEN\": \"${DT_API_TOKEN}\" }, \"name\": \"${secret_name}\", \"scope\": \"${scope}\"}"
}

function install_demo_cloudautomation {
  write_progress "Installing Cloud Automation Demo Projects"

  get_keptncredentials

  # set the parameters needed for install-cloudautomation-workshop.sh
  if [[ "$KEPTN_CONTROL_PLANE_DOMAIN" == "none" ]]; then 
    KEPTN_CONTROL_PLANE_DOMAIN=${KEPTN_DOMAIN:-none}
  fi 
  if [[ "$KEPTN_CONTROL_PLANE_API_TOKEN" == "none" ]]; then 
    KEPTN_CONTROL_PLANE_API_TOKEN=${KEPTN_API_TOKEN:-none}
  fi 

  if [[ "${KEPTN_EXECUTIONPLANE}" == "true" ]]; then
    KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN=${FQDN}
  else
    KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN=${KEPTN_DOMAIN:-none}
  fi

  export KEPTN_ENDPOINT="${PREFIX}://${KEPTN_DOMAIN}"
  export KEPTN_INGRESS=${FQDN}  

  # export those variables as we call another script
  export KEPTN_CONTROL_PLANE_DOMAIN="${KEPTN_CONTROL_PLANE_DOMAIN}"
  export KEPTN_CONTROL_PLANE_API_TOKEN="${KEPTN_CONTROL_PLANE_API_TOKEN}"
  export KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN="${KEPTN_EXECUTION_PLANE_INGRESS_DOMAIN}"

  # now install the cloud-automation-workshop with a single tenant
  currentDir=$(pwd)
  cd cloudautomation/scripts 
  ./install-cloudautomation-workshop.sh ./cloudautomation/scripts/tenants.stockssample_2.sh
  cd ${currentDir}

  # Also install the Argo Rollout example
  ./create-keptn-project-from-template.sh delivery-rollout ${OWNER_EMAIL} ${KEPTN_ROLLOUT_PROJECT}  

  # now trigger the delivery of the devops tools
  keptn trigger delivery --project=devopstools --service=keptnwebservice --image=grabnerandi/keptnwebservice --tag=2.0.1
}

function install_demo_dynatrace {
  write_progress "Installing Dynatrace Demo Projects"

  # ==============================================================================================
  # Demo 1: Create a quality-gate project called "dynatrace"
  # Setup based on https://github.com/keptn-contrib/dynatrace-sli-service/tree/master/dashboard
  # This project also enables the auto-synchronization capability as explained here: https://github.com/keptn-contrib/dynatrace-service#synchronizing-service-entities-detected-by-dynatrace
  # ==============================================================================================
  get_keptncredentials
  export KEPTN_ENDPOINT="${PREFIX}://${KEPTN_DOMAIN}"
  export KEPTN_INGRESS=${FQDN}
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_QG_PROJECT}"
  ./create-keptn-project-from-template.sh quality-gate-dynatrace ${OWNER_EMAIL} ${KEPTN_QG_PROJECT}

  echo "Run first Dynatrace Quality Gate"
  keptn trigger evaluation --project="${KEPTN_QG_PROJECT}" --stage="${KEPTN_QG_STAGE}" --service="${KEPTN_QG_SERVICE}" --timeframe=30m


  # ==============================================================================================
  # Demo 2: Performance as a Self-service Project
  # Creates a single stage project that will execute JMeter performance tests against any URL you give it
  # To get Keptn also send events to a Dynatrace Monitored Entity simply tag the entity with ${KEPTN_QG_STAGE}
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_PERFORMANCE_PROJECT}"
  ./create-keptn-project-from-template.sh performance-as-selfservice ${OWNER_EMAIL} ${KEPTN_PERFORMANCE_PROJECT}

  # ==============================================================================================
  # Demo 3: Auto-Remediation
  # Creates a single stage project with a service that will map to all incoming problem types, e.g: infrastructure, applcation ...
  # The service will have its own remediation.yaml to execute remediation scripts
  # This demo will leverage the generic-executor-service to execute bash or python scripts for remediation
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_REMEDIATION_PROJECT}"
  ./create-keptn-project-from-template.sh auto-remediation ${OWNER_EMAIL} ${KEPTN_REMEDIATION_PROJECT}

  # ==============================================================================================
  # Demo 4: Blue/Green Delivery with Istio
  # Creates a 3 stage delivery project to delivery the singlenode sample app in dev, staging and production
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_DELIVERY_PROJECT}"
  ./create-keptn-project-from-template.sh delivery-simplenode ${OWNER_EMAIL} ${KEPTN_DELIVERY_PROJECT}


  # ==============================================================================================
  # Demo 5: Canary Delivery with Argo Rollouts
  # Creates canary delivery project using Argo Rollouts
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_ROLLOUT_PROJECT}"
  ./create-keptn-project-from-template.sh delivery-rollout ${OWNER_EMAIL} ${KEPTN_ROLLOUT_PROJECT}

  # ==============================================================================================
  # Demo 6: Advanced Performance
  # Creates a project with 3 sequences of performance testing: functional, simple load, performance
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_ADV_PERFORMANCE_PROJECT}"
  ./create-keptn-project-from-template.sh advanced-performance ${OWNER_EMAIL} ${KEPTN_ADV_PERFORMANCE_PROJECT}

  # ==============================================================================================
  # Demo 7: Generic Automation
  # Creates a project that just shows generic automation sequences, e.g: calling some scripts
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_GENERIC_AUTOMATION_PROJECT}"
  ./create-keptn-project-from-template.sh generic-automation ${OWNER_EMAIL} ${KEPTN_GENERIC_AUTOMATION_PROJECT}

  # ==============================================================================================
  # Demo 8: Two Stage Delivery
  # Creates a project that uses a regular helm chart for two stage delivery
  # ==============================================================================================
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_TWOSTAGE_DELIVERY_PROJECT}"
  ./create-keptn-project-from-template.sh two-stage-delivery-simplenode ${OWNER_EMAIL} ${KEPTN_TWOSTAGE_DELIVERY_PROJECT}

}

function install_demo {
  echo "Installing Demos"

  if [[ "${DEMO}" == "dynatrace" ]]; then
    install_demo_dynatrace
  fi 

  if [[ "${DEMO}" == "cloudautomation" ]]; then
    install_demo_cloudautomation
  fi 

  if [[ "${DEMO}" == "prometheus" ]]; then
    install_prometheus_qg_demo
  fi 
}

function install_prometheus_qg_demo {
  write_progress "Installing Prometheus Demo Projects"

  export KEPTN_ENDPOINT="${PREFIX}://${KEPTN_DOMAIN}"
  export KEPTN_INGRESS=${FQDN}
  echo "----------------------------------------------"
  echo "Create Keptn Project: ${KEPTN_PROMETHEUS_QG_PROJECT}"
  ./create-keptn-project-from-template.sh prometheus-qg ${CERT_EMAIL} ${KEPTN_PROMETHEUS_QG_PROJECT}

  "${K3SKUBECTL[@]}" create secret -n keptn generic "prometheus-credentials-${KEPTN_PROMETHEUS_QG_PROJECT}" --from-file=prometheus-credentials="${TEMPLATE_DIRECTORY}/${KEPTN_PROMETHEUS_QG_PROJECT}/sli-secret.yaml"
  "${K3SKUBECTL[@]}" delete pod -n keptn --selector=run=prometheus-sli-service 

  "${K3SKUBECTL[@]}" create ns prometheus-qg-quality-gate
  "${K3SKUBECTL[@]}" apply -f "${TEMPLATE_DIRECTORY}/${KEPTN_PROMETHEUS_QG_PROJECT}/podtato-head/deployment.yaml"
  "${K3SKUBECTL[@]}" apply -f "${TEMPLATE_DIRECTORY}/${KEPTN_PROMETHEUS_QG_PROJECT}/podtato-head/service.yaml"

  # configure Prometheus monitoring
  keptn configure monitoring prometheus --project="${KEPTN_PROMETHEUS_QG_PROJECT}" --service="${KEPTN_PROMETHEUS_QG_SERVICE}"

  # expose Prometheus 
  PROMETHEUS_DOMAIN="prometheus.${FQDN}"
  write_progress "Configuring Prometheus Ingress Object (${PROMETHEUS_DOMAIN})"
    sed -e 's~domain.placeholder~'"$PROMETHEUS_DOMAIN"'~' \
        -e 's~issuer.placeholder~'"$CERTS"'~' \
        "${TEMPLATE_DIRECTORY}/${KEPTN_PROMETHEUS_QG_PROJECT}"/prometheus-ingress.yaml > prometheus-ingress_gen.yaml
    "${K3SKUBECTL[@]}" apply -n prometheus -f prometheus-ingress_gen.yaml
    rm prometheus-ingress_gen.yaml  

  # expose demo application
  PODTATO_DOMAIN="podtato.${FQDN}"
  write_progress "Configuring Podtato Ingress Object (${PODTATO_DOMAIN})"
    sed -e 's~domain.placeholder~'"$PODTATO_DOMAIN"'~' \
        -e 's~issuer.placeholder~'"$CERTS"'~' \
        "${TEMPLATE_DIRECTORY}/${KEPTN_PROMETHEUS_QG_PROJECT}"/podtato-ingress.yaml > podtato-ingress_gen.yaml
    "${K3SKUBECTL[@]}" apply -n ${KEPTN_PROMETHEUS_QG_PROJECT}-${KEPTN_QG_STAGE} -f podtato-ingress_gen.yaml
    rm podtato-ingress_gen.yaml  

  write_progress "Waiting for Prometheus server to be available (max 5 minutes)"
  "${K3SKUBECTL[@]}" wait --namespace=prometheus --for=condition=Available deploy/prometheus-server --timeout=300s --all   

  write_progress "Downloading hey load generation tool"
  curl https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 -o hey
  chmod +x hey

  sleep 3

  write_progress "Generating traffic for Podtato-head application (for 90 seconds)"
  ./hey -z 90s -c 10 "http://${PODTATO_DOMAIN}"

  echo "Run first Prometheus Quality Gate"
  keptn trigger evaluation --project="${KEPTN_PROMETHEUS_QG_PROJECT}" --stage="${KEPTN_PROMETHEUS_QG_STAGE}" --service="${KEPTN_PROMETHEUS_QG_SERVICE}" --timeframe=2m

  ### deploy slow version and evaluate it (this will be part of the tutorial and not automated here)
  # k3s kubectl set image deploy/helloservice server=gabrieltanner/hello-server:v0.1.2 --record -n prometheus-qg-quality-gate 
  # k3s kubectl wait --namespace=prometheus-qg-quality-gate --for=condition=Available deploy/helloservice --timeout=300s --all
  # ./hey -z 90s -c 10 "http://${PODTATO_DOMAIN}"
  # ./hey -z 90s -c 10 http://$(k3s kubectl get ingress podtato-ingress -n prometheus-qg-quality-gate -ojsonpath='{.spec.rules[0].host}')
  # keptn trigger evaluation --project="${KEPTN_PROMETHEUS_QG_PROJECT}" --stage="${KEPTN_PROMETHEUS_QG_STAGE}" --service="${KEPTN_PROMETHEUS_QG_SERVICE}" --timeframe=2m

}

function print_config {
  write_progress "Keptn Deployment Summary"
  BRIDGE_USERNAME="$(${K3SKUBECTL[@]} get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_USERNAME} --ignore-not-found | base64 -d)"
  BRIDGE_PASSWORD="$(${K3SKUBECTL[@]} get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_PASSWORD} --ignore-not-found | base64 -d)"

  get_keptncredentials

  echo "API URL   :      ${PREFIX}://${KEPTN_DOMAIN}/api"
  echo "Bridge URL:      ${PREFIX}://${KEPTN_DOMAIN}/bridge"
  echo "Bridge Username: $BRIDGE_USERNAME"
  echo "Bridge Password: $BRIDGE_PASSWORD"
  echo "API Token :      $KEPTN_API_TOKEN"

  echo "Ingress Domain:  ${FQDN}"

if [[ "${GITEA}" == "true" ]]; then
  echo "Git Server:      $GIT_SERVER"
  echo "Git User:        $GIT_USER"
  echo "Git Password:    $GIT_PASSWORD"
fi

  if [[ "${DEMO}" == "dynatrace" ]]; then
  write_progress "Dynatrace Demo Summary: 8 Use Cases to explore"
  cat << EOF
8 Dynatrace Demo projects have been created, the Keptn CLI has been downloaded and configured and a first demo quality gate was already executed.

------------------------------------------------------------------------
For the Quality Gate Use case you can do this:
1: Open the Keptn's Bridge for your Quality Gate Project: 
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_QG_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: Run another Quality Gate via: 
   keptn trigger evaluation --project=${KEPTN_QG_PROJECT} --stage=${KEPTN_QG_STAGE} --service=${KEPTN_QG_SERVICE}
3: Automatically synchronize your Dynatrace monitored services with Keptn by adding the 'keptn_managed' and 'keptn_service:SERVICENAME' tag
   More details here: https://github.com/keptn-contrib/dynatrace-service#synchronizing-service-entities-detected-by-dynatrace

------------------------------------------------------------------------
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

------------------------------------------------------------------------
For the Auto-Remediation Demo we have created project ${KEPTN_REMEDIATION_PROJECT} that contains a default remediation.yaml and some bash and python scripts
In order for this to work do
1: Create a new Problem Notification Integration as explained in the readme
2: Either force Dynatrace to open a problem ticket, create one through the API or execute ./dynatrace/createdtproblem.sh
3: Watch the auto-remediation actions in Keptn's bridge
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_REMEDIATION_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD

------------------------------------------------------------------------
For the Delivery Use Case using Istio we have created project ${KEPTN_DELIVERY_PROJECT} that allows you to deliver a simplenode app in 3 stages (dev, staging, production)
To trigger a delivery simple do this
1: Trigger a delivery through the Keptn CLI
   keptn trigger delivery --project=${KEPTN_DELIVERY_PROJECT} --stage=${KEPTN_DELIVERY_STAGE_DEV} --service=${KEPTN_DELIVERY_SERVICE} --image=docker.io/grabnerandi/simplenodeservice --tag=1.0.0
2: Watch the delivery progress in Keptn's bridge
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_DELIVERY_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD

------------------------------------------------------------------------
For the Canary Delivery Use Case using Argo Rollouts we have created project ${KEPTN_ROLLOUT_PROJECT} that deploys a simplenode app in 2 stages (blue/green in staging and canary in prod)
To trigger a delivery simple do this
1: Trigger a delivery through the Keptn CLI or the Keptn API as explained in the readme
   keptn trigger delivery --project=${KEPTN_ROLLOUT_PROJECT} --stage=${KEPTN_ROLLOUT_STAGE_STAGING} --service=${KEPTN_ROLLOUT_SERVICE} --image=docker.io/grabnerandi/simplenodeservice --tag=1.0.0
2: Watch the delivery progress in Keptn's bridge
   Project URL: ${PREFIX}://${KEPTN_DOMAIN}/bridge/project/${KEPTN_ROLLOUT_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
3: To deliver the next version simply run
   keptn trigger delivery --project=${KEPTN_ROLLOUT_PROJECT} --stage=${KEPTN_ROLLOUT_STAGE_STAGING} --service=${KEPTN_ROLLOUT_SERVICE} --image=docker.io/grabnerandi/simplenodeservice --tag=2.0.0

------------------------------------------------------------------------
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

------------------------------------------------------------------------
For the Generic Automation Use Case check out the project and trigger the fun sequence in dev
To trigger that sequence simply execute:
keptn send event --file=./dev.fun.triggered.json

------------------------------------------------------------------------
For the Two Stage Delivery Use Case check simply deploy the app via
1: keptn trigger delivery --project=${KEPTN_TWOSTAGE_DELIVERY_PROJECT} --stage=${KEPTN_TWOSTAGE_DELIVERY_STAGE_STAGING} --service=${KEPTN_TWOSTAGE_DELIVERY_SERVICE} --image=docker.io/grabnerandi/simplenodeservice --tag=1.0.0


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

To get access to your k3s via kubectl execute the following command:
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

Now go and enjoy Keptn!
EOF

}

function main {
  while true; do
  case "${1:-default}" in
    --type)
        INSTALL_TYPE="${2}"
        echo "Install Type: ${INSTALL_TYPE}"
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
  echo "Using FQDN: ${FQDN}"
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
        NIP="false"
        shift
        ;;
    --use-nip)
        echo "Using nip.io"
        XIP="false"
        NIP="true"
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
        if [[ "$KEPTN_CONTROL_PLANE_DOMAIN" == "none" ]]; then
          echo "To install an execution plane set KEPTN_CONTROL_PLANE_DOMAIN to the HOSTNAME of the Keptn Control Plane, e.g: keptn.yourdomain.com"
          exit 1
        fi 
        if [[ "$KEPTN_CONTROL_PLANE_API_TOKEN" == "none" ]]; then
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
        shift
        ;;
    --with-locust)
        echo "Enabling Locust Support"
        LOCUST="true"
        shift
        ;;
    --with-prometheus)
        echo "Enabling Prometheus Support"
        PROM="true"
        shift
        ;;
    --with-monaco)
        echo "Enabling Monaco Support"
        MONACO="true"
        check_dynatrace_credentials
        shift
        ;;
    --with-dynatrace)
        DYNA="true"
        MONACO="true"
        check_dynatrace_credentials
        shift
        ;;
    --with-gitea)
       GITEA="true"
       shift
       ;;
    --disable-bridge-auth)
       DISABLE_BRIDGE_AUTH="true"
       shift
       ;;
    --with-demo)
        DEMO="${2}"
        if [[ $DEMO != "dynatrace" ]] && [[ $DEMO != "prometheus" ]] && [[ $DEMO != "cloudautomation" ]] ; then 
          echo "--with-demo parameter currently supports: dynatrace, prometheus or cloudautomation. Value passed is not allowed"
          exit 1
        fi 

        if [[ $DEMO == "dynatrace" ]]; then 
          # need to make sure we install the generic exector service for our demo as well as jmeter
          GENERICEXEC="true"
          JOBEXECUTOR="true"
          JMETER="true"
          DYNA="true"
          MONACO="true"
          check_dynatrace_credentials          
         
          if [[ $OWNER_EMAIL == "none" ]]; then 
            echo "For installing the Dynatrace demo you need to export OWNER_EMAIL to a valid email of a Dynatrace User Account. The demo will create dashboards using that owner!"
            exit 1
          fi 
        fi        

        if [[ $DEMO == "cloudautomation" ]]; then 
          # need to make sure we install the locust service as well as monaco and dynatrace
          LOCUST="true"
          DYNA="true"
          MONACO="true"
          GENERICEXEC="true"
          JOBEXECUTOR="true"
          check_dynatrace_credentials          
         
          if [[ $OWNER_EMAIL == "none" ]]; then 
            echo "For installing the Cloud Automation demo you need to export OWNER_EMAIL to a valid email of a Dynatrace User Account. The demo will create dashboards using that owner!"
            exit 1
          fi 
        fi        

        echo "Demo: Installing demo projects for ${DEMO}"
        shift 2
        ;;
    --with-jobexec)
        JOBEXECUTOR="true"
        echo "Enabling Job Executor"
        shift
        ;;        
    --with-genericexec)
        GENERICEXEC="true"
        echo "Enabling Generic Executor"
        shift
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

    # NO LONGER NEEDED as we now have the auto git provisoiner!
    # if a GIT_SERVER is specified lets create repos
    # if [[ "${GIT_SERVER}" != "none" ]]; then
    #  gitea_readApiTokenFromFile
    #  gitea_createKeptnRepos
    #fi

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

    # NO LONGER NEEDED as we now have the auto git provisoiner!
    # if a GIT_SERVER is specified lets create repos
    # if [[ "${GIT_SERVER}" != "none" ]]; then
    #  gitea_readApiTokenFromFile
    #  gitea_createKeptnRepos
    #fi

    print_config    
  fi

}

main "${@}"
