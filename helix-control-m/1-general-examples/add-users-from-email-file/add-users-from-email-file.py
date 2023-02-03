#!/bin/python3
# read a txt file with email addresses (one per line), and add a new user to a Control-M SaaS environment for each email address
import requests
import json
import argparse
import os, sys
import getpass

# API URL - MODIFY THIS
ctmaapi_url = 'https://YOUR_TENANT-aapi.qa.controlm.com/automation-api' # must be https

# Parse command line arguments
parser = argparse.ArgumentParser(description='Updates Authorized Control-M/Servers list in multiple Agents')
parser.add_argument('-tf', '--tokenfile', dest='tokenfile', type=str, help='File that contains the API Key', required=False)
parser.add_argument('-m', '--mailfile',   dest='mailfile',  type=str, help='Input file containing list of email addresses to add', required=True)
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
    apitoken = getpass.getpass("API Key: ")

## Open Mail File
if not os.path.exists(args.mailfile):
    print("Unable to read the specified mailfile, %s, or file does not exist." % args.mailfile)
    sys.exit(1)
        
# Read mail file line for line, and call API request to add user for each line
with open(args.mailfile, "r") as f:
    lines = f.readlines() 
    for line in lines:
        emailaddress = line.strip(' \t\r\n\0')
        files = {'userFile': ('user.json', '{ "Name" : "'+emailaddress+'", "Roles" : ["Admin"] }' )}

        # Post add user request
        try:
            r = requests.post( ctmaapi_url+'/config/authorization/user',
                headers={"x-api-key" : apitoken}, 
                files = files )
        except Exception as err: # Catch any general errors
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            sys.exit(2)

        resp=json.loads(r.text)
        if( 'errors' in resp):
             message=resp['errors'][0]['message']
        else:
             message=resp['message']
        print("%s:\t%s" % (emailaddress, message) )

