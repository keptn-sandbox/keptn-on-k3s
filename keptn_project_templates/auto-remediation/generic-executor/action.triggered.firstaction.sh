#!/bin/bash

echo "This is the action handler for action $ACTION. Full action event available at $1"
echo "-------------------------------------------------------------------"
echo "Here some more context for our action: \$PID=${DATA_PROBLEM_PID}, \$CONTEXT=$SHKEPTNCONTEXT, \$SOURCE=$SOURCE, \$PROJECT=$DATA_PROJECT, \$SERVICE=$DATA_SERVICE, \$STAGE=$DATA_STAGE"
echo "Lets do some something against problem $DATA_PROBLEM_PROBLEMTITLE..."
echo "We also get the custom values from the remediation definition: CustomKey1=$DATA_ACTION_VALUE_CUSTOMKEY1, CustomKey2=$DATA_ACTION_VALUE_CUSTOMKEY2"