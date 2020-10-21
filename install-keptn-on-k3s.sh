#!/usr/bin/env bash

set -eu

DT_TENANT=${DT_TENANT:-none}
DT_API_TOKEN=${DT_API_TOKEN:-none}

BINDIR="/usr/local/bin"
KEPTNVERSION="0.7.2"
JMETER_SERVICE_BRANCH="feature/2552/jmeterextensionskeptn072"
KEPTN_API_TOKEN="$(head -c 16 /dev/urandom | base64)"
MY_IP="none"
FQDN="none"
K3SKUBECTL=("${BINDIR}/k3s" "kubectl")
PREFIX="https"
PROM="false"
DYNA="false"
JMETER="false"
CERTS="selfsigned"
SLACK="false"
XIP="false"
DEMO="false"
BRIDGE_PASSWORD="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml
LE_STAGE="none"

# keptn demo project defaults
KEPTN_QG_PROJECT="dynatrace"
KEPTN_QG_STAGE="quality-gate"
KEPTN_QG_SERVICE="demo"
KEPTN_PERFORMANCE_PROJECT="demo-performance"
KEPTN_PERFORMANCE_STAGE="performance"
KEPTN_PERFORMANCE_SERVICE="appundertest"
KEPTN_REMEDIATION_PROJECT="demo-remediation"
KEPTN_REMEDIATION_STAGE="production"
KEPTN_REMEDIATION_SERVICE="allproblems"
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
  echo "Waiting for Traefik to restart - 1st attempt"
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
  apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-sandbox/statistics-service/release-0.1.1/deploy/service.yaml"

    # Enable Monitoring support for either Prometheus or Dynatrace by installing the services and sli-providers
  if [[ "${PROM}" == "true" ]]; then
     write_progress "Installing Prometheus Service"
     apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/prometheus-service/release-0.3.5/deploy/service.yaml"
     apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/prometheus-sli-service/0.2.2/deploy/service.yaml "
  fi

  if [[ "${DYNA}" == "true" ]]; then
    write_progress "Installing Dynatrace Service"
    create_namespace dynatrace

    check_delete_secret dynatrace
    "${K3SKUBECTL[@]}" create secret generic -n keptn dynatrace \
      --from-literal="DT_TENANT=$DT_TENANT" \
      --from-literal="DT_API_TOKEN=$DT_API_TOKEN" \
      --from-literal="KEPTN_API_URL=${PREFIX}://$FQDN/api" \
      --from-literal="KEPTN_API_TOKEN=$(get_keptn_token)" \
      --from-literal="KEPTN_BRIDGE_URL=${PREFIX}://$FQDN/bridge"

    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/dynatrace-service/0.10.0/deploy/service.yaml"
    apply_manifest_ns_keptn "https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/0.7.0/deploy/service.yaml"

    # lets make Dynatrace the default SLI provider (feature enabled with lighthouse 0.7.2)
    "${K3SKUBECTL[@]}" create configmap lighthouse-config -n keptn --from-literal=sli-provider=dynatrace
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

  write_progress "Configuring Ingress Object (${FQDN})"

  cat << EOF |  "${K3SKUBECTL[@]}" apply -n keptn -f -
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
    - "${FQDN}"
    secretName: keptn-tls
  rules:
    - http:
        paths:
          - path: /
            backend:
              serviceName: api-gateway-nginx
              servicePort: 80
EOF

  write_progress "Waiting for objects to be ready"
  "${K3SKUBECTL[@]}" wait --namespace=keptn --for=condition=Ready pods --timeout=300s --all
}

function install_keptncli {
  KEPTN_API_TOKEN="$(get_keptn_token)"

  echo "Installing and Authenticating Keptn CLI"
  curl -sL https://get.keptn.sh | sudo -E bash
  keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${PREFIX}://$FQDN/api"
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

  KEPTN_ENDPOINT="${PREFIX}://${FQDN}"
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
  
  echo "Create a Dynatrace SLI/SLO Dashboard for ${KEPTN_QG_PROJECT}.${KEPTN_QG_STAGE}.${KEPTN_QG_SERVICE}"
  curl -fsSL -o /tmp/slo_sli_dashboard.json https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/master/dashboard/slo_sli_dashboard.json
  sed -i "s/\${KEPTN_PROJECT}/${KEPTN_QG_PROJECT}/" /tmp/slo_sli_dashboard.json
  sed -i "s/\${KEPTN_STAGE}/${KEPTN_QG_STAGE}/" /tmp/slo_sli_dashboard.json
  sed -i "s/\${KEPTN_SERVICE}/${KEPTN_QG_SERVICE}/" /tmp/slo_sli_dashboard.json
  sed -i "s/\${KEPTN_BRIDGE_PROJECT}/${KEPTN_BRIDGE_PROJECT_ESCAPED}/" /tmp/slo_sli_dashboard.json
  curl -X POST  ${DYNATRACE_ENDPOINT} -H "accept: application/json; charset=utf-8" -H "Authorization: Api-Token ${DYNATRACE_TOKEN}" -H "Content-Type: application/json; charset=utf-8" -d @/tmp/slo_sli_dashboard.json

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
      key: \$SERVICE
EOF
  keptn add-resource --project="${KEPTN_QG_PROJECT}" --resource=keptn/${KEPTN_QG_PROJECT}/dynatrace/dynatrace.conf.yaml --resourceUri=dynatrace/dynatrace.conf.yaml

  # remove temporary file
  rm /tmp/slo_sli_dashboard.json

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

  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/jmeter.conf.yaml https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/jmeter/jmeter.conf.yaml
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload.jmx https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/jmeter/basicload.jmx
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload_withdtmint.jmx https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/jmeter/basicload_withdtmint.jmx
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/jmeter.conf.yaml --resourceUri=jmeter/jmeter.conf.yaml
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload.jmx --resourceUri=jmeter/basicload.jmx
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/jmeter/basicload_withdtmint.jmx --resourceUri=jmeter/basicload_withdtmint.jmx

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
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/dynatrace/performance_sli.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/performance_sli.yaml
  curl -fsSL -o keptn/${KEPTN_PERFORMANCE_PROJECT}/performance_slo.yaml https://raw.githubusercontent.com/keptn-sandbox/keptn-on-k3s/dynatrace-support/files/performance_slo.yaml
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/dynatrace/performance_sli.yaml --resourceUri=dynatrace/sli.yaml
  keptn add-resource --project="${KEPTN_PERFORMANCE_PROJECT}" --stage="${KEPTN_PERFORMANCE_STAGE}" --service="${KEPTN_PERFORMANCE_SERVICE}" --resource=keptn/${KEPTN_PERFORMANCE_PROJECT}/performance_slo.yaml --resourceUri=slo.yaml

  # Download helper files to send a deployment finished event
  echo "Downloading helper script senddeployfinished.sh"
  curl -fsSL -o senddeployfinished.sh https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/events/senddeploymentfinished.sh
  curl -fsSL -o deployment.finished.event.placeholders.json https://raw.githubusercontent.com/keptn/keptn/${JMETER_SERVICE_BRANCH}/jmeter-service/events/deployment.finished.event.placeholder.json
  chmod +x senddeployfinished.sh
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

  echo "API URL   :      ${PREFIX}://${FQDN}/api"
  echo "Bridge URL:      ${PREFIX}://${FQDN}/bridge"
  echo "Bridge Username: $BRIDGE_USERNAME"
  echo "Bridge Password: $BRIDGE_PASSWORD"
  echo "API Token :      $KEPTN_API_TOKEN"

  if [[ "${DEMO}" == "dynatrace" ]]; then
  write_progress "Dynatrace Demo Summary"
  cat << EOF
The Dynatrace Demo projects have been created, the Keptn CLI has been downloaded and configured and a first demo quality gate was already executed.
Here are 3 things you can do:
1: Open the Keptn's Bridge for your Quality Gate Project: 
   Project URL: ${PREFIX}://${FQDN}/bridge/project/${KEPTN_QG_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: Run another Quality Gate via: 
   keptn send event start-evaluation --project=${KEPTN_QG_PROJECT} --stage=${KEPTN_QG_STAGE} --service=${KEPTN_QG_SERVICE}
3: Automatically synchronize your Dynatrace monitored services with Keptn by adding the 'keptn_managed' and 'keptn_service:SERVICENAME' tag
   More details here: https://github.com/keptn-contrib/dynatrace-service#synchronizing-service-entities-detected-by-dynatrace

For the Performance as a Self-Service Demo we have created a project that contains a simple JMeter test that can test a single URL.
Here are 3 things you can do:
1: Open the Keptn's Bridge for your Performance Project:
   Project URL: ${PREFIX}://${FQDN}/bridge/project/${KEPTN_PERFORMANCE_PROJECT}
   User / PWD: $BRIDGE_USERNAME / $BRIDGE_PASSWORD
2: In Dynatrace pick a service you want to run a simple test against and add the manual label: ${KEPTN_PERFORMANCE_SERVICE}
3: (optional) Create an SLO-Dashboard in Dynatrace with the name: KQG;project=${KEPTN_PERFORMANCE_PROJECT};service=${KEPTN_PERFORMANCE_SERVICE};stage=${KEPTN_PERFORMANCE_STAGE}
4: Trigger a Performance test for an application that is accessible from this machine, e.g. http://yourapp/yoururl
   ./senddeployfinished.sh ${KEPTN_PERFORMANCE_PROJECT} ${KEPTN_PERFORMANCE_STAGE} ${KEPTN_PERFORMANCE_SERVICE} performance_withdtmint http://yourapp/yoururl
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
- Authenticate: keptn auth  --api-token "${KEPTN_API_TOKEN}" --endpoint "${PREFIX}://$FQDN/api"

If you want to uninstall Keptn and k3s simply type: k3s-uninstall.sh!

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
    --with-demo)
        DEMO="${2}"
        if [[ $DEMO != "dynatrace" ]]; then 
          echo "--with-demo parameter currently supports: dynatrace. Value passed is not allowed"
          exit 1
        fi 
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
