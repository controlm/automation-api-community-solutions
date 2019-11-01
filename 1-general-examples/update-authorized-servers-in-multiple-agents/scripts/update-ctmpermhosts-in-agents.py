#!/bin/python3
import requests
import json
import urllib3
import argparse
import os
import getpass

# parameters - MODIFY THESE
ctmaapi_url = 'https://EMSERVER:8443/automation-api' # must be https

# parse command line arguments
parser = argparse.ArgumentParser(description='Updates Authorized Control-M/Servers list in multiple Agents')
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("-a", "--add", action="store_true", help='Add a host to the list')
group.add_argument("-d", "--delete", action="store_false", help='Delete a host from the list')
parser.add_argument('-u', '--username', dest='username', type=str, help='Username to login to Control-M/Enterprise Manager', required=True)
parser.add_argument('-pf', '--pwfile',  dest='pwfile',   type=str, help='The file that contains the password to login to Control-M/Enterprise Manager', required=False)
parser.add_argument('-i', '--insecure', dest='insecure', action='store_const', const=True, help='Disable TLS certificate verification', required=False)
parser.add_argument('-s', '--server',   dest='server',   type=str, help='Name of current Control-M/Server the Agents are connected to', required=True)
parser.add_argument('-n', '--newhost',  dest='newhost',  type=str, help='Host name to be added to the Authorized Control-M/Servers list', required=True)
args = parser.parse_args()


# Disable TLS certificate verification
if args.insecure:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
verifycert = not args.insecure

# Logout function
def ctmapi_logout():
    r = requests.post( ctmaapi_url+'/session/logout',
            headers={"Authorization": "Bearer "+token}, 
            verify=verifycert)

# Read password
if args.pwfile is not None:
    if not os.path.exists(args.pwfile):
        print("Unable to read the specified file, %s, or file does not exist." % args.pwfile)
    else:
        with open(args.pwfile, "r") as f:
            passwd = f.read()
            passwd = passwd.rstrip(' \t\r\n\0')
else:
    passwd = getpass.getpass("Password: ")


### LOGIN ### 
try: # start a try/except to catch specific expections related to the http connection
    r = requests.post( ctmaapi_url+'/session/login',
            json={"password": passwd, "username": args.username},
            verify=verifycert)
except requests.exceptions.SSLError as err: # If there is an SSL error.
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    print('INFO: add the certificate to this systems trusted CA store, or')
    print('if using a Self Signed Certificate use the -i flag to disable certificate verification')
    exit(1)
except Exception as err: # Catch any general errors
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    exit(2)

if 'errors' in json.loads(r.text):
    print("Unable to login") 
    print(json.dumps(json.loads(r.text)['errors'][0]['message'])) 
    exit(3) 
else:
    if 'token' in json.loads(r.text):
        token = json.loads(r.text)['token']
        passwd = None
        del passwd
    else:
        print('Unexpected response to login request: '+resp)
        exit(4)


### GET LIST OF AGENTS ###
try: # start a try/except to catch specific expections related to the http connection
    r = requests.get(ctmaapi_url+'/config/server/'+args.server+'/agents',
            headers={"Authorization": "Bearer "+token}, 
            verify=verifycert )
except Exception as err: # Catch any general errors
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    ctmapi_logout()
    exit(5)
resp=r.json()

if( resp['agents'] ):
    agents=resp['agents']
else:
    print('Unexpected response to agents get request: '+resp)
    ctmapi_logout()
    exit(6)


### Loop through Agents
for agent in agents:

    # skip Agent if status is not Available
    if( agent['status'] != 'Available' ):
        print( 'Agent '+agent['nodeid']+' status is '+agent['status']+', skipping...')
        continue  # skip to next agent

    # get Agent parameter list
    try: # start a try/except to catch specific expections related to the http connection
        r = requests.get(ctmaapi_url+'/config/server/'+args.server+'/agent/'+agent['nodeid']+'/params',
                headers={"Authorization": "Bearer "+token},
                verify=verifycert )
    except Exception as err: # Catch any general errors
        print("Connecting to Automation API REST Server failed with error: " + str(err))
        ctmapi_logout()
        exit(7)
    resp=r.json()

    # search CTMPERMHOSTS in list of parameters
    permhosts=next((item for item in resp if item['name'] == 'CTMPERMHOSTS'),None)

    if( not permhosts ):
        print('Unexpected response to agent/params request: '+resp)
        ctmapi_logout()
        exit(8)


    print( 'Agent '+agent['nodeid']+' current CTMPERMHOSTS value is: '+permhosts['value'])

    going_to_update=False
    permhost_array = permhosts['value'].split('|')

    # add or delete the new host to/from the list
    if( args.add ):
        if( not args.newhost in permhost_array):
             permhost_array.append(args.newhost) 
             going_to_update=True
        else:
             print( '  '+args.newhost+' already exists in CTMPERMHOSTS. Skipping...')
    else:
        if( args.newhost in permhost_array):
             # check that we're not removing the last hostname in the CTMPERMHOSTS list
             if( len(permhost_array)==1 ):
                 print( '  '+args.newhost+' cannot be removed, as CTMPERMHOSTS would become empty. Skipping...')
                 continue # skip to next agent
             permhost_array.remove(args.newhost)
             going_to_update=True
        else:
             print( '  '+args.newhost+' does not exist in CTMPERMHOSTS. Skipping...')

    # only update if value changed
    if( going_to_update ):
        updated_permhosts = '|'.join(permhost_array)
         
        # update Agent parameter 
        try: # start a try/except to catch specific expections related to the http connection
            r = requests.post(ctmaapi_url+'/config/server/'+args.server+'/agent/'+agent['nodeid']+'/param/CTMPERMHOSTS',
                    headers={"Authorization": "Bearer "+token},
                    json={'value': updated_permhosts},
                    verify=verifycert )
        except Exception as err: # Catch any general errors
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            ctmapi_logout()
            exit(9)
        resp=r.json()

        if( r.status_code != 200):
            print('Update failed with http code: ',r.status_code)
            exit(10)

        print('  Successfully updated CTMPERMHOSTS to: '+updated_permhosts )

exit(0)
