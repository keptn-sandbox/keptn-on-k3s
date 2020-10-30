
  #
  # Install Project for Auto-Remediation
  cat > /tmp/shipyard_remediation.yaml << EOF
stages:
- name: "${KEPTN_REMEDIATION_STAGE}"
  remediation_strategy: "automated"
EOF

  cat > /tmp/remediation.yaml << EOF
apiVersion: spec.keptn.sh/0.1.4
kind: Remediation
metadata:
  name: remediation-configuration
spec:
  remediations: 
  - problemType: "default"
    actionsOnOpen:
    - name: default
      action: notifyRemediation
      description: Default Action to notify about Remediation Action
      value:
        Message: This is a test message for the Remediation Action
EOF      

  echo "Create Keptn Project: ${KEPTN_REMEDIATION_PROJECT}"
  keptn create project "${KEPTN_REMEDIATION_PROJECT}" --shipyard=/tmp/shipyard_remediation.yaml

  echo "Create Keptn Service: ${KEPTN_REMEDIATION_SERVICE}"
  keptn create service "${KEPTN_REMEDIATION_SERVICE}" --project="${KEPTN_REMEDIATION_PROJECT}"

  echo "Upload Remediation.yaml"
