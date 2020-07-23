#!/usr/bin/env bash

BINDIR="/usr/local/bin"
KEPTNVERSION="0.7.0"
KEPTN_API_TOKEN="$(head -c 16 /dev/urandom | base64)"
MY_IP="none"
FQDN="none"
K3SKUBECTLCMD="${BINDIR}/k3s"
K3SKUBECTLOPT="kubectl"
PREFIX="https"
PROM="false"
DYNA="false"
JMETER="false"
CERTS="selfsigned"
SLACK="false"
BRIDGE_PASSWORD="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

function get_ip {
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

function get_fqdn {
  if [[ "$FQDN" == "none" ]]; then
    FQDN="${MY_IP}.xip.io"
    if [[ "${LE_STAGE}" == "production" ]]; then
      echo "Issuing Production LetsEncrypt Certificates with xip.io as domain is not possible"
      exit 1
    fi
  fi
}

function apply_manifest {
  if [[ ! -z $1 ]]; then
    "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" apply -f "${1}"
    if [[ $? != 0 ]]; then
      echo "Error applying manifest $1"
      exit 1
    fi
  fi
}

function get_k3s {
  curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable INSTALL_K3S_SYMLINK="skip" K3S_KUBECONFIG_MODE="644" sh -
}

function get_helm {
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh
}

function check_k8s {
  started=false
  while [[ ! "${started}" ]]; do
    sleep 5
    if "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" get nodes; then
      started=true
    fi
  done
}


function install_certmanager {
  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create namespace cert-manager
  apply_manifest https://github.com/jetstack/cert-manager/releases/download/v0.15.2/cert-manager.crds.yaml

  helm install cert-manager cert-manager \
    --create-namespace --namespace=cert-manager \
    --repo="https://charts.jetstack.io"

  cat << EOF | apply_manifest -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
  namespace: cert-manager
spec:
  selfSigned: {}
EOF

if [[ "$CERTS" == "letsencrypt" ]]; then
  if [[ "$LE_STAGE" == "production" ]]; then
    ACME_SERVER="https://acme-v02.api.letsencrypt.org/directory"
  else
    ACME_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
  fi

  cat << EOF | apply_manifest -
apiVersion: cert-manager.io/v1alpha2
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
}

function install_keptn {
  
  helm install keptn keptn \
    --create-namespace --namespace=keptn \
    --repo="https://storage.googleapis.com/keptn-installer" \
    --kubeconfig /etc/rancher/k3s/k3s.yaml
  sleep 10
  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" wait --namespace=keptn  --for=condition=Ready pods --timeout=300s --all


  # Enable Monitoring support for either Prometheus or Dynatrace by installing the services and sli-providers
  if [[ "${PROM}" == "true" ]]; then
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/prometheus-service/release-0.3.5/deploy/service.yaml"
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/prometheus-sli-service/0.2.2/deploy/service.yaml"
  fi

  if [[ "${DYNA}" == "true" ]]; then
    echo "Installing Dynatrace OneAgent Operator"
    helm install dynatrace-oneagent-operator dynatrace-oneagent-operator \
      --create-namespace --namespace=dynatrace \
      --repo="https://raw.githubusercontent.com/Dynatrace/helm-charts/master/repos/stable" \
      --set platform="kubernetes" \
      --set oneagent.apiUrl="https://${DT_TENANT}/api" \
      --set secret.apiToken="${DT_API_TOKEN}" \
      --set secret.paasToken="${DT_PAAS_TOKEN}"

    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/dynatrace-service/0.8.0/deploy/service.yaml"
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/0.5.0/deploy/service.yaml"
  fi

  if [[ "${SLACK}" == "true" ]]; then
    apply_manifest "https://raw.githubusercontent.com/keptn-sandbox/slackbot-service/0.1.2/deploy/slackbot-service.yaml"
    "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create secret generic -n keptn slackbot --from-literal="slackbot-token=$SLACKBOT_TOKEN"
  fi

  # Installing JMeter Extended Service
  if [[ "${JMETER}" == "true" ]]; then
    apply_manifest "https://raw.githubusercontent.com/keptn/keptn/0.7.0/jmeter-service/deploy/service.yaml"
  fi

  cat << EOF |  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" apply -n keptn -f -
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: keptn-ingress
  annotations:
    cert-manager.io/cluster-issuer: $CERTS-issuer
    traefik.ingress.kubernetes.io/redirect-entry-point: https
spec:
  tls:
  - hosts:
    - ${FQDN}
    secretName: keptn-tls
  rules:
    - http:
        paths:
          - path: /
            backend:
              serviceName: api-gateway-nginx
              servicePort: 80
EOF

  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" wait --namespace=keptn --for=condition=Ready pods --timeout=300s --all
}

function print_config {
  BRIDGE_USERNAME="$(${K3SKUBECTLCMD} ${K3SKUBECTLOPT} get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_USERNAME} | base64 -d)"
  BRIDGE_PASSWORD="$(${K3SKUBECTLCMD} ${K3SKUBECTLOPT} get secret bridge-credentials -n keptn -o jsonpath={.data.BASIC_AUTH_PASSWORD} | base64 -d)"
  KEPTN_API_TOKEN="$(${K3SKUBECTLCMD} ${K3SKUBECTLOPT} get secret keptn-api-token -n keptn -o jsonpath={.data.keptn-api-token} | base64 -d)"

  echo "API URL   :      ${PREFIX}://${FQDN}/api"
  echo "Bridge URL:      ${PREFIX}://${FQDN}/bridge"
  echo "Bridge Username: $BRIDGE_USERNAME"
  echo "Bridge Password: $BRIDGE_PASSWORD"
  echo "API Token :      $KEPTN_API_TOKEN"

  cat << EOF
To use keptn:
- Install the keptn CLI: curl -sL https://get.keptn.sh | sudo -E bash
- Authenticate: keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${PREFIX}://$FQDN/api"
EOF
}

function main {
  while true; do
  case "$1" in
    --ip)
        MY_IP="${2}"
        shift 2
      ;;
    --provider)
        case "${2}" in
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
            echo "Provider: DigitalOcean"
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
        echo "Enabling Dynatrace Support: Requires you to set DT_TENANT, DT_API_TOKEN, DT_PAAS_TOKEN"
        if [[ "$DT_TENANT" == "" ]]; then
          echo "You have to set DT_TENANT to your Tenant URL, e.g: abc12345.dynatrace.live.com or yourdynatracemanaged.com/e/abcde-123123-asdfa-1231231"
          echo "To learn more about the required settings please visit https://keptn.sh/docs/0.7.x/monitoring/dynatrace/install"
          exit 1
        fi
        if [[ "$DT_API_TOKEN" == "" ]]; then
          echo "You have to set DT_API_TOKEN to a Token that has read/write configuration, access metrics, log content and capture request data priviliges"
          echo "If you want to learn more please visit https://keptn.sh/docs/0.7.x/monitoring/dynatrace/install"
          exit 1
        fi
        if [[ "$DT_PAAS_TOKEN" == "" ]]; then
          echo "You have to set DT_PAAS_TOKEN"
          echo "If you want to learn more please visit https://keptn.sh/docs/0.7.x/monitoring/dynatrace/install"
          exit 1
        fi

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

  get_ip
  get_fqdn
  get_k3s
  get_helm
  check_k8s
  install_certmanager
  install_keptn
  print_config
}

main "${@}"
