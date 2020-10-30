#!/bin/bash

echo "This script gets called for the remediation action: $ACTION for PID=$PID ($PROBLEMTITLE)"
echo "Full action event available at $1"
echo "-------------------------------------------------------------------"
echo "Here some more context for our action: \$PID=${PID}, \$CONTEXT=$CONTEXT, \$SOURCE=$SOURCE, \$PROJECT=$PROJECT, \$SERVICE=$SERVICE, \$STAGE=$STAGE"
echo "Lets do some something against problem $PROBLEMTITLE..."