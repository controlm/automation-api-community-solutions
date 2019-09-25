import requests
import json
import urllib3
import argparse
import os
import getpass

# Parse command line arguments
parser = argparse.ArgumentParser(description='Some explanation of what the python script does')
parser.add_argument('-u', '--username', dest='username', type=str, help='Username to login to Control-M/Enterprise Manager')
parser.add_argument('-pf', '--pwfile', dest='pwfile', type=str, help='The file that contains the password to login to Control-M/Enterprise Manager')
parser.add_argument('-h', '--host', dest='host', type=str, help='Control-M/Enterprise Manager hostname')
parser.add_argument('-i', '--insecure', dest='insecure', action='store_const', const=True, help='Disable SSL Certification Verification')
args = parser.parse_args()

# Error handling
# 1. Supress insecure request warning
if args.insecure:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
verifycert = not args.insecure

if args.pwfile is not None:
    if not os.path.exists(args.pwfile):
        print("Unable to read the specified file, %s, or file does not exist." % args.pwfile)
    else:
        with open(args.pwfile, "r") as f:
            passwd = f.read()
            passwd = passwd.rstrip(' \t\r\n\0')
else:
    passwd = getpass.getpass("Password: ")

# Login to the API
try: # start a try/except to catch specific expections related to the http connection
    r = requests.post('https://'+host+':8443/automation-api/session/login', 
            json={"password": passwd, "username": args.username},
            verify=verifycert)
except requests.exceptions.ConnectTimeout as err: # If the connection times out waiting for the response from the server
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    exit(1)
except requests.exceptions.SSLError as err: # If there is an SSL error.
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    print('INFO: If using a Self Signed Certificate use the -i flag to disable cert verification or \ # If you have created a flag or config file option to disable tls/ssl validation,
            add the certificate to this systems trusted CA store') #  this is a good place to hint to the user that they may want to use it
    exit(1)
except requests.exceptions.HTTPError as err: # Catch any general HTTP errors like 500/400 responces
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    exit(1)

if 'errors' in json.loads(r.text): # Check if the response contains an object named "error"
    print("Unable to login!") # if so, print a reason able message based on the action that was just attempted
    print(json.dumps(json.loads(r.text)['errors'][0]['message'])) # then print the value of the message key for the json object(s) inside of the errors array
    quit(1) # quit/exit the program if desired. (Retry logic could be implemented here instead of a quit())
else:
    # Logic/Actions on the result, json.loads(r.text), go here
    if 'token' in json.loads(r.text):
        token = json.loads(r.text)['token']
        passwd = None
        del passwd
    else:
        print("Could not retreive token")
        quit(1)


