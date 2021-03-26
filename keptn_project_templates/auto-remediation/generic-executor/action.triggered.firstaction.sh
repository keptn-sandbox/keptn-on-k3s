#!/bin/bash

echo "This is the action handler for action $ACTION. Full action event available at $1"
echo "-------------------------------------------------------------------"
echo "Here some more context for our action: \$PID=${PID}, \$CONTEXT=$CONTEXT, \$SOURCE=$SOURCE, \$PROJECT=$PROJECT, \$SERVICE=$SERVICE, \$STAGE=$STAGE"
echo "Lets do some something against problem $PROBLEMTITLE..."
echo "We also get the custom values from the remediation definition: CustomKey1=$VALUE_CUSTOMKEY1, CustomKey2=$VALUE_CUSTOMKEY2"