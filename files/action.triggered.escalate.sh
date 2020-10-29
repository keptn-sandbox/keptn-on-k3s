#!/bin/bash

echo "This script gets called for the remediation action: $ACTION for PID=$PID ($PROBLEMTITLE)"
echo "Full action event available at $1"
echo "-------------------------------------------------------------------"
echo "This script is meant to be used to ESCALATE the issue"
echo "Here is where we would add more actions to e.g: inform people ..."