import os
import sys

# Lets get the first parameter which could potentially be a local file name
methodArg = ""
if len(sys.argv) > 1:
    methodArg = sys.argv[1]

print("This is my poweroutage handler script and I got passed " + methodArg + " as parameter")
print("I also have some env variables, e.g: PID=" + os.getenv('PID', "") + ", CONTEXT=" + os.getenv('CONTEXT', ""))
print("SOURCE=" + os.getenv('SOURCE',""))
print("PROJECT=" + os.getenv('PROJECT',""))
print("PROBLEMTITLE=" + os.getenv('PROBLEMTITLE',""))
print("And here is the message that was passed as part of the remediation action definition :" + os.getenv("VALUE_MESSAGE", "NO MESSAGE"))