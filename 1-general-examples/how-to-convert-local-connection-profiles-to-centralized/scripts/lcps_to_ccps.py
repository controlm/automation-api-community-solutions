#! python3.8

import requests
import json
import urllib3
import argparse
import os
import getpass
from pprint import pprint
from functools import reduce
from copy import deepcopy
from datetime import datetime

# Parameters:
ctmaapi_url = 'https://SERVER:8443/automation-api' # Replace "SERVER" with your server name

nowStr = datetime.now().strftime("%m_%d_%YT%H_%M_%S")
logfileName = "log-" + str(nowStr) + ".txt"

# Parse command line arguments
parser = argparse.ArgumentParser(description='Conversion of local connection profiles to centralized connection profiles')
parser.add_argument('-u', '--username', dest='username', type=str, help='Username for login to Control-M/Enterprise Manager', required=True)
parser.add_argument('-p', '--password', dest='password', type=str, help='Password for login to Control-M/Enterprise Manager', required=True)
parser.add_argument('-c', '--ctm',      dest='ctm',      type=str, help='Name of Control-M/Server', required=True)
parser.add_argument('-a', '--agent',    dest='agent',    type=str, help='Name of host or alias of the Control-M/Agent', required=True)
parser.add_argument('-t', '--type',    dest='type',    type=str, help='Type of local connection profiles. You can choose from the following types of connection profiles: AWS, ApplicationIntegrator:SISnet, Azure, Database, FileTransfer, Hadoop, Informatica, SAP', required=True)
parser.add_argument('-i', '--insecure', dest='insecure', action='store_const', const=True, help='Disable TLS certificate verification', required=False)
args = parser.parse_args()

# Disable TLS certificate verification
if args.insecure:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
verifycert = not args.insecure

# Print & write logs in console and log file
def printLog(*args, **kwargs):
    print(*args, **kwargs)
    with open(logfileName,'a') as file:
        print(*args, **kwargs, file=file)

# Logout function
def ctmapi_logout():
    try: 
        r = requests.post( ctmaapi_url+'/session/logout',
                headers={'Authorization': 'Bearer '+token}, 
                verify=verifycert)
    except Exception as err: # Catch any general errors
        printLog('Connecting to Automation API REST Server failed with error: ' + str(err))
        exit(1)
    printLog('User \"' + args.username + '\" logged-out\n')

# Login
try: # start a try/except to catch specific expections related to the http connection
    r = requests.post(ctmaapi_url+'/session/login',
            json={'password': args.password, 'username': args.username},
            verify=verifycert)

except Exception as err: # Catch any general errors
    if 'Failed to establish a new connection' in str(err):
        printLog('Connecting to Automation API REST Server failed - please check "ctmaapi_url" parameter at the beginning of the script')
    else:
        printLog('Connecting to Automation API REST Server failed with error: ' + str(err))
    exit(2)

if 'errors' in json.loads(r.text):
    printLog('Unable to login') 
    printLog(json.dumps(json.loads(r.text)['errors'][0]['message'])) 
    exit(3) 
else:
    if 'token' in json.loads(r.text):
        token = json.loads(r.text)['token']
        passwd = None
        printLog('User \"' + args.username + '\" logged-in\n')
    else:
        printLog('Unexpected response to login request: '+ r)
        exit(4)

printLog('Step 1 - Gets a list of local connection profiles by type \"' + args.type + '\" from Control-M:')
printLog('----------')
try: # Start a try/except to catch specific expections related to the http connection
    searchquery='ctm='+args.ctm+'&agent='+args.agent+'&type='+args.type

    r = requests.get(ctmaapi_url+'/deploy/connectionprofiles/local?'+searchquery,
            headers={'Authorization': 'Bearer '+token}, 
            verify=verifycert)
            
except Exception as err: # Catch any general errors
    printLog('Connecting to Automation API REST Server failed with error: ' + str(err))
    ctmapi_logout()
    exit(5)
    
lcps=r.json()
if 'errors' in json.loads(r.text):
    printLog('No local connection profile found')
    printLog(json.dumps(json.loads(r.text)['errors'][0]['message']),'\n') 
    ctmapi_logout()
    exit(6)    
elif( len(lcps)==0):
    printLog('No local connection profile found\n')
    ctmapi_logout()
    exit(7)

printLog(len(lcps), 'Local connection profiles were found\n')

printLog('Step 2 - Converts local connection profiles of type \"' + args.type + '\" to centralized connection profiles:')
printLog('----------')
def convert(acc, lcpName): 
    lcp=lcps[lcpName]
    acc[lcpName]=lcp
    if (lcp['Type']!=None and lcp['Type'].startswith('ConnectionProfile')):
        ccp=deepcopy(lcp)
        acc[lcpName]=ccp
        ccp['Centralized']=True
        ccp.pop('TargetAgent', None)
        ccp.pop('TargetCTM', None)
        # When getting connection profiles from Control-M, all password definitions are hidden. 
        # You MUST replace all hidden passwords with real passwords or secrets.
        ccp['Password']={'Secret': lcpName.lower()+'_secret'}
    return acc

ccps=reduce(convert, lcps.keys(), {})
printLog(len(lcps), 'Local connection profiles were converted\n')

printLog('Step 3 - Writes the converted list of centralized connection profiles in a temporary json file:')
printLog('----------')
tempFile = open('temp.json', 'w')
tempFile.write('%s' % (json.dumps(ccps, indent=4)))
tempFile.close()
printLog('temp.json file is ready! *** PLEASE REVIEW IT\'S CONTENT ***\n')

printLog('Step 4 - Builds (that is, validates) the converted list of centralized connection profiles:')
printLog('----------')
try: # Start a try/except to catch specific expections related to the http connection
    r=requests.post(ctmaapi_url+'/build',
        headers={'Authorization': 'Bearer '+token}, 
        files={'definitionsFile': open('temp.json', 'rb')},
        verify=verifycert)

except Exception as err: # Catch any general errors
    printLog('Connecting to Automation API REST Server failed with error: ' + str(err))
    ctmapi_logout()
    exit(8)

printLog('Build result:\n'+r.text)

printLog('\nBefore you continue, please review the temp.json file...')
answer = input('Do you want to deploy centralized connection profiles to Control-M (Y/N)? ')
if answer != 'Y' and answer != 'y':
    printLog('\nBye')
    exit(9)

printLog('\nStep 5 (Optional) - Deploys validated centralized connection profiles to Control-M.')
printLog('----------')
try: # Start a tssry/except to catch specific expections related to the http connection
    r=requests.post(ctmaapi_url+'/deploy',
        headers={'Authorization': 'Bearer '+token}, 
        files={'definitionsFile': open('temp.json', 'rb')},
        verify=verifycert)

except Exception as err: # Catch any general errors
    printLog('Connecting to Automation API REST Server failed with error: ' + str(err))
    ctmapi_logout()
    exit(10)

printLog('Deploy result:\n'+r.text+'\n')

ctmapi_logout()
printLog('Done')
exit(0)