#!/bin/python3
# example Python code for starting a script to communiocate with Control-M AAPI.
# reads command-line arguments, then reads API Token and sends an example API request.
import requests
import json
import argparse
import os, sys
import getpass

# API URL - MODIFY THIS
ctmaapi_url = 'https://YOURTENANT-aapi.us1.controlm.com/automation-api' 

# Parse command line arguments
parser = argparse.ArgumentParser(description='Updates Authorized Control-M/Servers list in multiple Agents')
parser.add_argument('-tf', '--tokenfile', dest='tokenfile', type=str, help='File that contains the API Key', required=False)
args = parser.parse_args()


# Read API Token from file, if given. Else, request token from user interactively (without echoing input)
if args.tokenfile is not None:
    if not os.path.exists(args.tokenfile):
        print("Unable to read the specified file, %s, or file does not exist." % args.tokenfile)
    else:
        with open(args.tokenfile, "r") as f:
            apitoken = f.read()
            apitoken = apitoken.rstrip(' \t\r\n\0')
else:
    apitoken = getpass.getpass("API Token: ")

# Example get roles request (make sure the token has config authorizations)
try:
    r = requests.get( ctmaapi_url+'/config/authorization/roles',
        headers={"x-api-key" : apitoken})
except Exception as err: # Catch any general errors
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    sys.exit(1)

resp=json.loads(r.text)
print("Get Roles Response:")
print(json.dumps(resp,indent=4))

