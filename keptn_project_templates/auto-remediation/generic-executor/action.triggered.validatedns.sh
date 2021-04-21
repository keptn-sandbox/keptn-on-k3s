#!/bin/bash

echo "This script gets called for the remediation action: $DATA_ACTION_ACTION for PID=$DATA_PROBLEM_PID ($DATA_PROBLEM_PROBLEMTITLE)"
echo "Full action event available at $1"
echo "-------------------------------------------------------------------"
echo "Here some more context for our action: \$PID=${DATA_PROBLEM_PID}, \$SHKEPTNCONTEXT=$SHKEPTNCONTEXT, \$SOURCE=$SOURCE, \$PROJECT=$DATA_PROJECT, \$SERVICE=$DATA_SERVICE, \$STAGE=$DATA_STAGE"
echo "Lets do some something against problem $DATA_PROBLEM_PROBLEMTITLE..."