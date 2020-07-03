#!/usr/bin/env bash

BINDIR="/usr/local/bin"
KEPTNVERSION="0.6.2"
KEPTN_API_TOKEN="$(head -c 16 /dev/urandom | base64)"
MY_IP="none"
K3SKUBECTLCMD="${BINDIR}/k3s"
K3SKUBECTLOPT="kubectl"
PREFIX="http"
PROM="false"
DYNA="false"
JMETER="false"
CERTS="selfsigned"
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

function check_k8s {
  started=false
  while [[ ! "${started}" ]]; do
    sleep 5
    if "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" get nodes; then
      started=true
    fi
  done
}

function generate_certificate {
  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/O=keptn/CN=*.{MY_IP}.xip.io" -keyout /tmp/certificate.key -out /tmp/certificate.crt
  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create secret tls keptn-tls -n keptn --cert /tmp/certificate.crt --key /tmp/certificate.key
  rm /tmp/certificate.crt /tmp/certificate.key
}

function install_certmanager {
  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create namespace cert-manager
  apply_manifest https://github.com/jetstack/cert-manager/releases/download/v0.15.2/cert-manager.crds.yaml

  cat << EOF |  apply_manifest -
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  chart: cert-manager
  repo: https://charts.jetstack.io
EOF

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
  use_cert=false
  # Keptn Quality Gate installation based on https://keptn.sh/docs/develop/operate/manifest_installation/
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/keptn/namespace.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/keptn/rbac.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/nats/nats-operator-prereqs.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/nats/nats-operator-deploy.yaml"
  sleep 20
  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" wait --namespace=keptn -l name=nats-operator  --for=condition=Ready pods --timeout=300s --all

  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/nats/nats-cluster.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/logging/namespace.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/logging/mongodb/pvc.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/logging/mongodb/deployment.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/logging/mongodb/svc.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/logging/mongodb-datastore/k8s/mongodb-datastore.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/logging/mongodb-datastore/mongodb-datastore-distributor.yaml"
  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" wait --namespace=keptn-datastore --for=condition=Ready pods --timeout=300s --all

  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create secret generic -n keptn keptn-api-token --from-literal=keptn-api-token="${KEPTN_API_TOKEN}"
  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create secret generic -n keptn bridge-credentials --from-literal=BASIC_AUTH_USERNAME="keptn" --from-literal=BASIC_AUTH_PASSWORD="${BRIDGE_PASSWORD}"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/keptn/core.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/keptn/keptn-domain-configmap.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/keptn/api-gateway-nginx.yaml"
  apply_manifest "https://raw.githubusercontent.com/keptn/keptn/${KEPTNVERSION}/installer/manifests/keptn/quality-gates.yaml"

  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create clusterrolebinding --serviceaccount=keptn:default --clusterrole=cluster-admin keptn-cluster-rolebinding

  # Enable Monitoring support for either Prometheus or Dynatrace by installing the services and sli-providers
  if [[ "${PROM}" == "true" ]]; then
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/prometheus-service/release-0.3.4/deploy/service.yaml"
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/prometheus-sli-service/0.2.2/deploy/service.yaml"
  fi

  if [[ "${DYNA}" == "true" ]]; then
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/dynatrace-service/0.7.1/deploy/manifests/dynatrace-service/dynatrace-service.yaml"
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/0.4.2/deploy/service.yaml"
    
    "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" create secret generic -n keptn dynatrace --from-literal="DT_TENANT=$DT_TENANT" --from-literal="DT_API_TOKEN=$DT_API_TOKEN"
  fi

  # Installing JMeter Extended Service
  if [[ "${JMETER}" == "true" ]]; then
    apply_manifest "https://raw.githubusercontent.com/keptn-contrib/jmeter-extended-service/release-0.2.0/deploy/service.yaml"
  fi

  cat << EOF | "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" apply -n keptn -f -
apiVersion: v1
data:
  app_domain: ${MY_IP}.xip.io
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: keptn-domain
  namespace: keptn
EOF

  cat << EOF |  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" apply -n keptn -f -
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: keptn-ingress
  annotations:
    cert-manager.io/cluster-issuer: $CERTS-issuer
spec:
  tls:
  - hosts:
    - api.keptn.${MY_IP}.xip.io
    - bridge.keptn.${MY_IP}.xip.io
    secretName: keptn-tls
  rules:
    - host: api.keptn.${MY_IP}.xip.io
      http:
        paths:
          - path: /
            backend:
              serviceName: api-gateway-nginx
              servicePort: 80
    - host: api.keptn
      http:
        paths:
          - path: /
            backend:
              serviceName: api-gateway-nginx
              servicePort: 80
    - host: bridge.keptn.${MY_IP}.xip.io
      http:
        paths:
          - path: /
            backend:
              serviceName: bridge
              servicePort: 8080
EOF

  "${K3SKUBECTLCMD}" "${K3SKUBECTLOPT}" wait --namespace=keptn --for=condition=Ready pods --timeout=300s --all
}

function print_config {
  echo "API URL   :      ${PREFIX}://api.keptn.$MY_IP.xip.io"
  echo "Bridge URL:      ${PREFIX}://bridge.keptn.$MY_IP.xip.io"
  echo "Bridge Username: keptn"
  echo "Bridge Password: $BRIDGE_PASSWORD"
  echo "API Token :      $KEPTN_API_TOKEN"

  cat << EOF
To use keptn:
- Install the keptn CLI: curl -sL https://get.keptn.sh | sudo -E bash
- Authenticate: keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${PREFIX}://api.keptn.$MY_IP.xip.io"
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
        echo "Enabling Dynatrace Support: Requires you to set DT_TENANT, DT_API_TOKEN"
        if [[ "$DT_TENANT" == "" ]]; then
          echo "You have to set DT_TENANT to your Tenant URL, e.g: abc12345.dynatrace.live.com or yourdynatracemanaged.com/e/abcde-123123-asdfa-1231231"
          echo "To learn more about the required settings please visit https://keptn.sh/docs/0.6.0/reference/monitoring/dynatrace/"
          exit 1
        fi 
        if [[ "$DT_API_TOKEN" == "" ]]; then
          echo "You have to set DT_API_TOKEN to a Token that has read/write configuration, access metrics, log content and capture request data priviliges"
          echo "If you want to learn more please visit https://keptn.sh/docs/0.6.0/reference/monitoring/dynatrace/"
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
    *)
      break
      ;;
  esac
  done

  get_ip
  get_k3s
  check_k8s
  install_certmanager
  install_keptn
  print_config
}

main "${@}"
