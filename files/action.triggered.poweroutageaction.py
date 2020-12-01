import os
import sys

# Lets get the first parameter which could potentially be a local file name
methodArg = ""
if len(sys.argv) > 1:
    methodArg = sys.argv[1]

print("This is the output of my poweroutage action handler python called for " + os.getenv('PROBLEMTITLE',""))
print("Received the following message from the remediation action definition: "+ os.getenv("VALUE_MESSAGE", "NO MESSAGE"))
print("This output will be part of the Dynatrace Problem Comment.")
print("You can even pass links via markdown: [Click me](https://www.keptn.sh)")

# Following are some more examples on environment variables
# print("I also have some env variables, e.g: PID=" + os.getenv('PID', "") + ", CONTEXT=" + os.getenv('CONTEXT', ""))
# print("SOURCE=" + os.getenv('SOURCE',""))
# print("PROJECT=" + os.getenv('PROJECT',""))
# print("PROBLEMTITLE=" + os.getenv('PROBLEMTITLE',""))
