import boto3
import collections
import datetime
import json
from botocore.vendored import requests
import os, tempfile, zipfile, contextlib, io

s3client = boto3.client('s3')
secretsclient = boto3.client('secretsmanager')
verbose = False
verify_certs = False
ctmresponse = 200
s3res = boto3.resource('s3')
CTMEnvironment = 'none'
CTMServer = 'none'
ReqType = 'none'
Jobname = 'none'
Folder = 'none'
Template = 'none'
CTMEvent = 'none'
CTMOdate = 'none'
S3WatchBucket = 'none'
S3WatchFile = 'none'

def lambda_handler(event, context):
    if verbose:
        print("ctmEventHandler received event: " + json.dumps(event, indent=2))
        
    try:
        eventSource = event['Records'][0]['EventSource']
        if eventSource == 'aws:sns':
            SNSMessage = event['Records'][0]['Sns']['Message']
            event = json.loads(SNSMessage)
        else:
            print("Uppercase EventSource but not an SNS version 1.0 event")    
    except:
        print("Not an SNS version 1.0 event")
        
    eventSource = event['Records'][0]['eventSource']
    if verbose:
        print("Processing this event: " + json.dumps(event, indent=2))
    
    if eventSource == 'aws:sqs':
        ctmreq = sqs_event(event)
        ctmresponse = do_request(ctmreq)
    elif eventSource == 'aws:sns':
        ctmreq = sns_event(event)
        ctmresponse = do_request(ctmreq)
    elif eventSource == 'aws:s3':
        ctmreq = s3_event(event)
        ctmresponse = do_request(ctmreq)
    else:
        print("Unexpected event type: " + eventSource)
        ctmresponse = 400
    
    response = {
        "statusCode": ctmresponse,
        "body": json.dumps(event)
    }
    
    return response
    
def sqs_event(event):
    global CTMEnvironment, CTMServer, ReqType, Jobname, Folder, Template, CTMEvent, CTMOdate
    msgbody = event['Records'][0]['body']
    if verbose:
        print("Message body: " + msgbody)
    #
    #aws sqs send-message --queue-url "https://us-west-2.queue.amazonaws.com/623469066856/ctmrequests" --message-body "{\"Request\": [{\"Environment\" : \"ctmprod\",  \"RequestAttributes\" : { \"ControlmServer\" : \"workbench\", \"Type\" : \"runjob\", \"Jobname\" : \"ALL\",   \"Folder\" : \"payroll\" }}]}"
    #
    msgpayload = json.loads(msgbody)
    CTMEnvironment = msgpayload['Request'][0]['Environment']
    CTMServer = msgpayload['Request'][0]['RequestAttributes']['ControlmServer']
    ReqType = msgpayload['Request'][0]['RequestAttributes']['Type']
    Jobname = msgpayload['Request'][0]['RequestAttributes']['Jobname']
    Folder = msgpayload['Request'][0]['RequestAttributes']['Folder']
    if verbose:
        print("Environment: " + CTMEnvironment + " - Control-M Server: " + CTMServer + " - Request type: " + ReqType + " - Jobname: " + Jobname + " - Folder: " + Folder)
    
    if ReqType == 'createjob':
        Template = msgpayload['Request'][0]['RequestAttributes']['Template']
        
    ctmrequest_args = collections.namedtuple('Ctmrequest_Args', ['CTMEnvironment', 'CTMServer', 'ReqType', 'Jobname', 'Folder', 'Template', 'CTMEvent', 'CTMOdate', 'S3WatchBucket', 'S3WatchFile'])
    ctmreq = ctmrequest_args(CTMEnvironment, CTMServer, ReqType, Jobname, Folder, Template, CTMEvent, CTMOdate, S3WatchBucket, S3WatchFile)
        
    return ctmreq
    
def sns_event(event):
    global CTMEnvironment, ReqType, Jobname, Folder, Template, Event, CTMOdate

    return
    
def s3_event(event):
    global CTMEnvironment, ReqType, Jobname, Folder, Template, CTMEvent, CTMOdate
    S3WatchBucket = event['Records'][0]['s3']['bucket']['name']
    S3WatchFile = event['Records'][0]['s3']['object']['key']
    if verbose:
        print("S3 info: " + S3WatchBucket + " " + S3WatchFile)
        
    CTMSecret = str("CTMS3Watch-" + S3WatchBucket)
    
    secret_response = secretsclient.get_secret_value(SecretId=CTMSecret)
    ctminfo = secret_response['SecretString']
    ctmData = json.loads(ctminfo)
    CTMEnvironment = ctmData['CTMEnvironment']
    CTMServer = ctmData['CTMServer']
    ReqType = ctmData['Putaction']
    if ReqType == 'addevent':
        CTMEvent = ctmData['CTMEvent']
        CTMOdate = ctmData['CTMOdate']
    if ReqType == 'runjob':
        Jobname = ctmData['Jobname']
        Folder = ctmData['Folder']
    if ReqType == 'createjob':
        Jobname = ctmData['Jobname']
        Folder = ctmData['Folder']
        Template = ctmData['Template']
        
    ctmrequest_args = collections.namedtuple('Ctmrequest_Args', ['CTMEnvironment', 'CTMServer', 'ReqType', 'Jobname', 'Folder', 'Template', 'CTMEvent', 'CTMOdate', 'S3WatchBucket', 'S3WatchFile'])
    ctmreq = ctmrequest_args(CTMEnvironment, CTMServer, ReqType, Jobname, Folder, Template, CTMEvent, CTMOdate, S3WatchBucket, S3WatchFile)
        
    return ctmreq
    
#
#------------------------------------------------------------------------------------------------
#   do_request performs the Control-M request that is the result of an SQS, SNS or S3 event
#   Request parameters set up in source-specific routines
#       CTM Environment: 
#       CTMServer:
#       Request Type:
#       Job:
#       Folder:
#       Job Template:
#       Event:
#       Order Date:
#------------------------------------------------------------------------------------------------
#
def do_request(ctmreq):
    CTMEnvironment = ctmreq.CTMEnvironment
    CTMServer = ctmreq.CTMServer
    ReqType = ctmreq.ReqType
    Jobname = ctmreq.Jobname
    Folder = ctmreq.Folder
    Template = ctmreq.Template
    CTMEvent = ctmreq.CTMEvent
    CTMOdate = ctmreq.CTMOdate
    S3WatchBucket = ctmreq.S3WatchBucket
    S3WatchFile = ctmreq.S3WatchFile
    auth = build_auth(CTMEnvironment)
    ctmtoken = ctm_login(auth)
    
    if ReqType == 'runjob':
        ctmresponse = run_ctm_job(ctmtoken, auth.baseurl, CTMServer, Jobname, Folder)
    elif ReqType == 'createjob':
        template_json = get_job_template(Template, auth.bucket, Folder, Jobname, S3WatchBucket, S3WatchFile)
        ctmresponse = ctm_create_job(template_json, ctmtoken, auth.baseurl)
    elif ReqType == 'addevent':
        ctmresponse = ctm_addevent(ctmreq, ctmtoken, auth.baseurl)
        
    response = ctm_logout(ctmtoken, auth)
    
    return response
    
def build_auth(CTMEnvironment):
    CTMSecret = str("CTMEnvironment_" + CTMEnvironment)
    secret_response = secretsclient.get_secret_value(SecretId=CTMSecret)
    ctminfo = secret_response['SecretString']
    ctmData = json.loads(ctminfo)
    ctmEndpoint = ctmData['endpoint']
    username = ctmData['username']
    password = ctmData['password']
    bucket = ctmData['bucket']
    baseurl = ctmEndpoint
    login_args = collections.namedtuple('Login_Args', ['baseurl', 'username', 'password', 'bucket'])
    auth = login_args(baseurl, username, password, bucket)
    return auth  # return auth info as named tuple
    
def ctm_login(auth):
    global verbose
    baseurl = auth.baseurl
    username = auth.username
    password = auth.password

    loginurl = baseurl + 'session/login'  # The login url
    body = json.loads('{ "password": "' + password + '", "username": "' + username + '"}')  # create a json object to use as the body of the post to the login url
    
    if verbose:
        print('Base URL: ' + baseurl)
        print('Body: ' + json.dumps(body))
    
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
        
    return exit
    
def run_ctm_job(ctmtoken, baseurl, CTMServer, Jobname, Folder):
    global verbose
    response = 200
    rjoburl = baseurl + 'run/order'
    hdrdata = {'Content-type': 'application/json'}
    hdrtoken = 'Bearer '+ ctmtoken
    hdrdata.update(Authorization=hdrtoken)
    if Jobname == 'ALL':
        Jobname = '*'
    body = json.loads('{"folder":"' + Folder + '", "jobs":"' + Jobname + '", "ctm":"' + CTMServer +'"}')
    
    
    if verbose:
        print('Run job via URL: ' + rjoburl)
        print('Header: ' + json.dumps(hdrdata))
        print('Body:' + json.dumps(body))
    try:    
        rcRunJob = requests.post(rjoburl, json=body, headers=hdrdata, verify=verify_certs)  # Order a job
    except:
        print("Ordering a job encountered an error: ")
        RJresponce = json.loads(rcRunJob.text)
        if 'errors' in RJresponse:
            print(json.dumps(RJresponse['errors'][0]['message']))
                
    if verbose:
        print(rcRunJob.text)
        print(rcRunJob.status_code)
    
    return response
    
def ctm_create_job(template_json, ctmtoken, baseurl):
    global verbose
    rjoburl = baseurl + 'run'
    hdrdata = json.loads('{"Authorization": "Bearer ' + ctmtoken + '"}')
    jobJsonStr = json.dumps(template_json)
    #print("Json str: " + jobJsonStr)
    jobJsonStream = io.StringIO(jobJsonStr)
    jobJsonFile = [('jobDefinitionsFile', ('jobs.json', jobJsonStream, 'application/json'))]
    r = requests.post(rjoburl, files=jobJsonFile, headers=hdrdata, verify=verify_certs)
    print(r.status_code)
    print(r.text)
    print(r.content)

    return r.status_code

def get_job_template(template, bucket, Folder, Jobname, S3WatchBucket, S3WatchFile):
    content_object = s3res.Object(bucket, template)
    if verbose:
        print("get_job_template parms: " + template + " " + bucket + " " + Folder + " " + Jobname + " " + S3WatchBucket + " " + S3WatchFile)
    template_str = content_object.get()['Body'].read().decode('utf-8')
    if Folder != 'none':
        template_str = template_str.replace('VAR_FOLDER_VAR', Folder)
    if Jobname != 'none' and Jobname != 'ALL':
        template_str = template_str.replace('VAR_JOBPFX_VAR', Jobname)
    if S3WatchBucket != 'none':
        template_str = template_str.replace('VAR_S3BUCKET_VAR', S3WatchBucket)
    if S3WatchFile != 'none':
        template_str = template_str.replace('VAR_S3FILE_VAR', S3WatchFile)
    
    template_json = json.loads(template_str)
    
    return template_json  # return 