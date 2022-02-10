from __future__ import print_function

import boto3
import botocore
import collections
import datetime
import json
import requests
from botocore.exceptions import ClientError

print('Loading ctmAgentCleanup function')

BUCKET = 'controlm-automationapi-tutorial-artifacts'
verbose = True
verify_certs = False

ec2res = boto3.resource('ec2')
s3client = boto3.client('s3')

def lambda_handler(event, context):
    global ctmenv, ctmsrv, ctmhgrp, ctmagent
    state = event['detail']['state']
    instanceid = event['detail']['instance-id']
    print("Instance ID = " + instanceid)
    print("State = " + state)
    if state == 'shutting-down':
        instancedata = get_ec2_info(instanceid)
        ctmenv = instancedata.ctmenvname
        ctmsrv = instancedata.ctmserver
        ctmhgrp = instancedata.ctmhgrpname
        ec2host = instancedata.pvthost
        ctmagent = ec2host + ":" + instanceid
        print("Control-M Environment: " + ctmenv)
        print("Control-M Server: " + ctmsrv)
        print("Control-M Hostgroup: " + ctmhgrp)
        print("Control-M Agent: " + ctmagent)
    
        if ec2host != "":
            auth = build_login(instancedata)
            if verbose:
                print("Control-M Environment: " + auth.baseurl)
                print("Control-M Username: " + auth.username)
                print("Control-M Password: " + auth.password)
            ctmtoken = ctm_login(auth)
            delete_agent(ctmtoken, auth.baseurl)
            ctm_logout(ctmtoken, auth)
        else:
            print("EC2 Hostname not available")
            
    return event['detail']  # Return something
            
def get_ec2_info(fid):
    ec2instance = ec2res.Instance(fid)
    pvtdns = ec2instance.private_dns_name
    pvthost = pvtdns.split(".")[0]
    if verbose:
        print("Private DNS: " + pvtdns)
        print("EC2 Host:" + pvthost)
    
    ctmenvname = ''
    ctmsrvname = ''
    ctmhgrpname = ''
    for tag in ec2instance.tags:
        if tag['Key'] == 'ctmenvironment':
            ctmenvname = tag['Value']
        if tag['Key'] == 'ctmserver':
            ctmserver = tag['Value']
        if tag['Key'] == 'ctmhostgroup':
            ctmhgrpname = tag['Value']
    
    ec2_info = collections.namedtuple('EC2_Info', ['ctmenvname', 'ctmserver', 'ctmhgrpname', 'pvthost'])
    ec2info = ec2_info(ctmenvname, ctmserver, ctmhgrpname, pvthost)
    return ec2info  # return auth info as named tuple
    
def build_login(instancedata):
    ctmenv = instancedata.ctmenvname
    secret_name = ctmenv + "_password"
    KEY = ctmenv + ".login"         # Construct S3 Key
    result = s3client.get_object(Bucket=BUCKET, Key=KEY)
    ctmendpoint = result["Body"].read().decode('utf-8')
    json_ctmendpoint = json.loads(ctmendpoint)
    print("Endpoint info: " + json.dumps(json_ctmendpoint, indent=2))
    ctmhost = json_ctmendpoint['host']
    username = json_ctmendpoint['username']
    password = get_secret(secret_name)
    baseurl = 'https://' + ctmhost + ':8443/automation-api/'
    login_args = collections.namedtuple('Login_Args', ['baseurl', 'username', 'password'])
    auth = login_args(baseurl, username, password)
    return auth  # return auth info as named tuple

def ctm_login(auth):
    global verbose
    baseurl = auth.baseurl
    username = auth.username
    password = auth.password

    if verbose:
        print('base URL: ' + baseurl)

    loginurl = baseurl + 'session/login'  # The login url
    body = json.loads('{ "password": "' + password + '", "username": "' + username + '"}')  # create a json object to use as the body of the post to the login url
    
    try:
        r = requests.post(loginurl, json=body, verify=verify_certs)
    except requests.exceptions.ConnectTimeout as err:
        print("Connecting to Automation API REST Server failed with error: " + str(err))
        quit(1)
        
    except requests.exceptions.ConnectionError as err:
        print("Connecting to Automation API REST Server failed with error: " + str(err))
        if 'CERTIFICATE_VERIFY_FAILED' in str(err.message):
            print('INFO: If using a Self Signed Certificate set verify_certs to False to disable cert verification or add the certificate to this systems trusted CA store')
        quit(1)
    except requests.exceptions.HTTPError as err:
        print("Connecting to Automation API REST Server failed with error: " + str(err))
        quit(1)
    except:
        print("Connecting to Automation API REST Server failed with error unknown error")
        quit(1)

    if verbose:
        print(r.text)
        print(r.status_code)

    loginresponce = json.loads(r.text)
    if 'errors' in loginresponce:
        print(json.dumps(loginresponce['errors'][0]['message']))
        quit(1)

    if 'token' in loginresponce:  # If token exists in the json response set the value to the variable token
        token = json.loads(r.text)['token']
    else:
        print("Failed to get token for unknown reason, exiting...")
        quit(2)

    if verbose:
        print('Token: ' + token)

    return token  # return the token
    
def delete_agent(token, baseurl):
    global verbose
    hgrpurl = baseurl + 'config/server/' + ctmsrv + '/hostgroup/' + ctmhgrp + '/agent/' + ctmagent
    data = json.loads('{"Authorization": "Bearer ' + token + '"}')  # the jobs statues call should have the token in the header as JSON    

    if verbose:
        print('DelAgent from Hostgroup URL: ' + hgrpurl)
        print('Header: ' + json.dumps(data))
    try:    
        rcDelAgentfromHGroup = requests.delete(hgrpurl, headers=data, verify=verify_certs)  # Delete agent from Hostgroup
    except:
        print("Deleteing agent from hostgroup encountered an error: ")
        
    agdelurl = baseurl + 'config/server/' + ctmsrv + '/agent/' + ctmagent
    try:
        rcDelAgentfromServer = requests.delete(agdelurl, headers=data, verify=verify_certs)  # Delete agent from Server
    except:
        print("Deleteing agent from server encountered an error: ")
        
    if verbose:
        print('Del Agent from Server URL: ' + agdelurl)
        print('Header: ' + json.dumps(data))
        print('RC DelAgentFromHostgroup: ' + rcDelAgentfromHGroup)
        print('RC DelAgentFromServer: ' + rcDelAgentfromServer)
    
def ctm_logout(token, auth, exit=0):
    # if logged in, need to call logout before quiting to invalidate the token for security
    # this prevents the chance of intercepting a token and being reused later
    
    global verbose
    baseurl = auth.baseurl
    username = auth.username
    logouturl = baseurl + 'session/logout'  # Automation API logout url
    
    if verbose:
        print('Logout URL: ' + logouturl)

    body = json.loads('{ "token": "' + token + '", "username": "' + username + '"}')  # logout url needs json with the token and username
    
    r4 = requests.post(logouturl, data=body, verify=verify_certs)  # a post on this url invalidates the token with the above json as the post data
    if verbose:
        print(r4.headers)

    if verbose:
        print(r4.text)
        
    quit(exit)

def get_secret(secret_name):
    
    endpoint_url = "https://secretsmanager.us-west-2.amazonaws.com"
    region_name = "us-west-2"

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name,
        endpoint_url=endpoint_url
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            print("The requested secret " + secret_name + " was not found")
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            print("The request was invalid due to:", e)
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            print("The request had invalid params:", e)
    else:
        # Decrypted secret using the associated KMS CMK
        # Depending on whether the secret was a string or binary, one of these fields will be populated
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
        else:
            binary_secret_data = get_secret_value_response['SecretBinary']
		
    print("smdemo_em_password is: " + secret)
    return secret