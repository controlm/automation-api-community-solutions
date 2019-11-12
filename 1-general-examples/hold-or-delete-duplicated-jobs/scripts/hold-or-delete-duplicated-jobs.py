#!/bin/python3
import requests
import json
import operator
import urllib3
import argparse
import os
import getpass
from pprint import pprint

# parameters - MODIFY THESE
ctmaapi_url = 'https://EMHOST:8443/automation-api' # must be https

undo_filename = 'undofile.txt'

# parse command line arguments
parser = argparse.ArgumentParser(description='Identifies jobs ordered as duplicate for a given Control-M datacenter and Folder, and Holds or Deletes the job.')
parser.add_argument('-u', '--username', dest='username', type=str, help='Username to login to Control-M/Enterprise Manager', required=True)
parser.add_argument('-pf', '--pwfile',  dest='pwfile',   type=str, help='The file that contains the password to login to Control-M/Enterprise Manager', required=False)
parser.add_argument('-i', '--insecure', dest='insecure', action='store_const', const=True, help='Disable TLS certificate verification', required=False)
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("-o", "--hold",      action="store_true", help='Hold the jobs')
group.add_argument("-d", "--delete",    action="store_false", help='Mark the jobs for deletion')
parser.add_argument('-s', '--ctm',      dest='ctm',      type=str, help='Control-M datacenter on which the jobs reside', required=True)
parser.add_argument('-f', '--folder',   dest='folder',   type=str, help='Folder name from which the jobs were ordered', required=True)
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


### GET LIST OF JOBS ###
searchquery='ctm='+args.ctm+'&folder='+args.folder
try: # start a try/except to catch specific expections related to the http connection
    r = requests.get(ctmaapi_url+'/run/jobs/status?'+searchquery,
            headers={"Authorization": "Bearer "+token}, 
            verify=verifycert )
except Exception as err: # Catch any general errors
    print("Connecting to Automation API REST Server failed with error: " + str(err))
    ctmapi_logout()
    exit(5)
resp=r.json()

if( resp.get('statuses') ):
    jobslist=resp['statuses']
elif( resp.get('total')==0 ):
    print('No jobs found for folder '+args.folder)
    ctmapi_logout()
    exit(0)
else:
    print('Unexpected response to jobs status request: '+resp)
    ctmapi_logout()
    exit(6)


### FIND DUPLICATES

# add sorting key to list
for j in range(len(jobslist)):
    pprint( jobslist[j] )
    (discard,jobslist[j]['orderId'])=jobslist[j]['jobId'].split(':',1)
    jobslist[j]['sortkey']=jobslist[j]['name']+jobslist[j]['host']+':'+jobslist[j]['orderDate']+':'+jobslist[j]['jobId']

# sort jobs on name and orderid
jobslist.sort(key=operator.itemgetter('sortkey'))

# The following code determines the jobs are duplicate based on: jobname, host (nodeid) and order Date (odate)
# Be careful when modifying an test whether it achieves the desired reesul in your environment!
keep=[]
dups=[]
for j in range(len(jobslist)):
    if(j==0):
        keep.append(jobslist[j])
    else:
        if(jobslist[j]['name']==jobslist[j-1]['name'] and jobslist[j]['host']==jobslist[j-1]['host'] and jobslist[j]['orderDate']==jobslist[j-1]['orderDate']) :
            dups.append(jobslist[j])
        else:
            keep.append(jobslist[j])

print("%d total jobs found" % len(jobslist))
print("%d considered as duplicate based on jobname, host and odate\n" % len(dups))

if(len(dups)==0):
    ctmapi_logout()
    exit(0)

if(args.hold):
    action='hold'
else:
    action='delete'


### Display number of jobs that matched query, and ask to continue Y/N
print("This will %s %d jobs on the Control-M active environment." % (action, len(dups)))
if(len(dups)>50):
    print("Warning! Updating this many jobs may take a long time.\n")
response=''
while( (response!='y' and response!='n' and response!='yes' and response!='no') ):
    response = input("Do you want to continue? Yes or No: ").lower()

if( response[0]=='n' ):
    ctmapi_logout()
    exit(0)

# open undo log file
undo_file = open(undo_filename, "w")

### Loop through duplicate Jobs
for job in dups:
    job_succesfully_held=False
    job_succesfully_deleted=False

    #** HOLD JOB (run job::hold) **
    try: # start a try/except to catch specific expections related to the http connection
        r = requests.post(ctmaapi_url+'/run/job/'+job['jobId']+'/hold',
                headers={"Authorization": "Bearer "+token},
                verify=verifycert )
    except Exception as err: # Catch any general errors
        print("Connecting to Automation API REST Server failed with error: " + str(err))
        ctmapi_logout()
        exit(7)
    resp=r.json()

    if(r.status_code==200):
        job_succesfully_held=True

    if( not resp.get('message') ):
        if( 'ALREADY HELD' in str(resp) ):
            message = 'Job already held'
        else:
            print('Unexpected response to hold request: '+str(resp))
            ctmapi_logout()
            exit(8)
    else:
        message = resp['message']

    print( message )

    if(action=='delete'):
        #** DELETE JOB (run job::delete) **
        try: # start a try/except to catch specific expections related to the http connection
            r = requests.post(ctmaapi_url+'/run/job/'+job['jobId']+'/delete',
                    headers={"Authorization": "Bearer "+token},
                    verify=verifycert )
        except Exception as err: # Catch any general errors
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            ctmapi_logout()
            exit(7)
        resp=r.json()

        if(r.status_code==200):
            job_succesfully_deleted=True
    
        if( not resp.get('message') ):
            print('Unexpected response to hold request: '+str(resp))
            ctmapi_logout()
            exit(8)

        print( resp['message'] )

        if(job_succesfully_deleted):
            undo_file.write("ctm run job::undelete %s\n" % job['jobId'])

    if(job_succesfully_held):
        undo_file.write("ctm run job::free %s\n" % job['jobId'])
        
#close undo log file        
undo_file.close()
exit(0)

