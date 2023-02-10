# Basic imports
import json
import sys
import logging

# To write the log and output to files for attaching.
import tempfile
import os
from os import getcwd, path
from socket import getfqdn

# Importing Control-M Python Client
from ctm_python_client.core.workflow import *
from ctm_python_client.core.comm import *
from ctm_python_client.core.monitoring import Monitor
from aapi import *

# Importing functions
from extalert_functions import args2dict
from extalert_functions import parsing_args
from extalert_functions import init_dbg_log
from extalert_functions import dbg_assign_var

#Not just the RemedyAPI from pipy
from remedy_py.RemedyAPIClient import RemedyClient as itsm_cli

# To see if we need to set initial debug. If not, can be set at tktvars,
#    but logging will not be as throrough in the beginning.
# need to pip install python-dotenv
from dotenv import dotenv_values

# Set exit code for the procedure
exitrc = 0

# Initialize logging
dbg_logger=init_dbg_log()

try:
    env_file = getcwd() + path.sep + '.env.debug'
    config = dotenv_values(env_file)  # could render config = {"DEBUG": "true"}
    dbg_logger.info(f'file {env_file} was loaded. Setting debug to {config["DEBUG"]}.')
    debug = True if config['DEBUG'] == 'true' else False
except:
    dbg_logger.info(f'file {env_file} is not available. Setting debug to False.')
    config = {}
    config['DEBUG'] = 'false'
    debug = False

# Setting logging level according to .env
if debug:
    dbg_logger.setLevel(logging.DEBUG)
    dbg_logger.info('Startup logging to file level adjusted to debug (verbose)')
else:
    dbg_logger.setLevel(logging.INFO)
    dbg_logger.info('Startup logging to file level is INFO')

try:
    dbg_logger.info('Opening field_names.json')
    with open('field_names.json') as keyword_data:
        json_keywords = json.load(keyword_data)
        dbg_logger.debug('Fields file is ' + str(json_keywords))
        keywords = []
        keywords_json = {}
        for i in range(len(json_keywords['fields'])):
            element=[*json_keywords['fields'][i].values()]
            keywords.append(element[0]+':')
            keywords_json.update(json_keywords['fields'][i])
except FileNotFoundError as e:
    # Template file with fields not found
    # Assuming all fields will be passed in standard order
    dbg_logger.info('Failed opening field_names.json. Using default')
    keywords_json = dbg_assign_var( { {'eventType': 'eventType'}, {'id': 'alert_id'}, {'server': 'server'},
                    {'fileName': 'fileName'}, {'runId': 'runId'}, {'severity': 'severity'},
                    {'status': 'status'}, {'time': 'time'}, {'user': 'user'}, {'updateTime': 'updateTime'},
                    {'message': 'message'}, {'runAs': 'runAs'}, {'subApplication': 'subApplication'},
                    {'application': 'application'}, {'jobName': 'jobName'}, {'host': 'host'}, {'type': 'type'},
                    {'closedByControlM': 'closedByControlM'}, {'ticketNumber': 'ticketNumber'}, {'runNo': 'runNo'},
                    {'notes': 'notes'} }, "Default field names used internally", dbg_logger, debug)
    keywords = dbg_assign_var(['eventType:', 'id:', 'server:', 'fileName:', 'runId:', 'severity:', 'status:',
            'time:', 'user:' ,'updateTime:' ,'message: ' ,'runAs:' ,'subApplication:' ,'application:',
            'jobName:', 'host:', 'type:', 'closedByControlM:', 'ticketNumber:', 'runNo:', 'notes:'],
            'Default field names assigned.', dbg_logger, debug)

try:
    dbg_logger.info('Opening tktvars.json')
    with open('tktvars_dco.json') as config_data:
        config=json.load(config_data)
        dbg_logger.debug('Config file is ' + str(config_data))
except FileNotFoundError as e:
    dbg_logger.info('Failed opening tktvars.json')
    dbg_logger.info('Exception: No config file (tktvars.json) found.')
    dbg_logger.info(e)
    sys.exit(24)

if (config['pgmvars']['crttickets'] == 'no'):
    dbg_logger.info ('*' * 20 + ' Alert not sent to ticketing system.')
    dbg_logger.info()
    exitrc = 12
    sys.exit(exitrc)

#Set debug mode. It will be shown in the log. DO NOT POLLUTE!
if (config['pgmvars']['debug'] == 'yes'):
    debug = True
    dbg_logger.setLevel(logging.DEBUG)
    dbg_logger.debug('Startup logging level adjusted to debug by Config File')
else:
    debug = False
    dbg_logger.setLevel(logging.INFO)
    dbg_logger.debug('Logging level is INFO')

if (config['pgmvars']['ctmattachlogs'] == 'yes'):
    ctmattachlogs = True
    dbg_logger.info ('Log and output will be attached to the ticket.')
else:
    ctmattachlogs = False
    dbg_logger.info ('Log and output will NOT be attached to the ticket.')

if (config['pgmvars']['addtkt2alert'] == 'yes'):
    addtkt2alert = True
    dbg_logger.info ('Ticket ID will be added to the alert.')
else:
    addtkt2alert = False
    dbg_logger.info ('Ticket ID will NOT be added to the alert.')

if (config['pgmvars']['ctmupdatetkt'] == 'yes'):
    ctmupdatetkt = True
    dbg_logger.info ('Updates will be sent to the system.')
else:
    ctmupdatetkt = False
    dbg_logger.info ('Updates will NOT be sent to the system.')


# Ticket variables from tktvars.json
tkt_url = dbg_assign_var(config['tktvars']['tkturl'], 'Ticketing URL',dbg_logger, debug)
tkt_port = dbg_assign_var(config['tktvars']['tktport'],"Ticketing port", dbg_logger, debug)
tkt_user = dbg_assign_var(config['tktvars']['tktuser'],"Ticketing user", dbg_logger, debug)
tkt_pass = config['tktvars']['tktpasswd']
#NewLine for RITSM messages
NL='\n';

# Configure RITSM client
itsm_client = itsm_cli(host=tkt_url, port=tkt_port, username=tkt_user, password=tkt_pass, verify=True)

# Load ctmvars
#   Set AAPI variables and create workflow object
host_name = config['ctmvars']['ctmaapi']
api_token = config['ctmvars']['ctmtoken']
ctm_is_helix = True if config['ctmvars']['ctmplatform'] == "Helix" else False
w = Workflow(Environment.create_saas(endpoint=f"https://{host_name}",api_key=api_token,))
monitor = Monitor(aapiclient=w.aapiclient)

#   Set host for web url
ctmweb=config['ctmvars']['ctmweb']

# Evaluate alert and convert args to list
args = ''.join(map(lambda x: str(x)+' ', sys.argv[1:]))
# Convert Alert to dict using keywords.
alert = args2dict(args, keywords)

#breakpoint()

#print (type(args), args)

#print (type(alert),alert)

alert_id = alert['id']
dbg_logger.debug('params: ' + args)
dbg_logger.debug('dict is ' + str(alert))

# Exit if alert should not be sent.
if (ctmupdatetkt and alert[keywords_json['eventType']]):
    exitrc = 24
    sys.exit(exitrc)


#### Build Ticket fields
tkt_category=dbg_assign_var('Service Interruption', 'Ticket category', dbg_logger, debug, alert_id)
tkt_urgency=dbg_assign_var('1-Critical', 'Ticket Urgency', dbg_logger, debug, alert_id)
tkt_impact=dbg_assign_var('1-Extensive/Widespread', 'Ticket Impact', dbg_logger, debug, alert_id)
tkt_watch_list=dbg_assign_var('dcompane@gmail.com', 'Ticket watchlist (RITSM specific)', dbg_logger, debug, alert_id)
tkt_work_list=dbg_assign_var('dcompazrctm@gmail.com', 'Ticket worklist (RITSM specific)', dbg_logger, debug, alert_id)
tkt_assigned_group=dbg_assign_var('CTM GROUP', 'Ticket assigned group (RITSM specific)', dbg_logger, debug, alert_id)
tkt_short_description=dbg_assign_var(f"{alert[keywords_json['jobName']]} {alert[keywords_json['message']]}",
                        'Ticket Short Description', dbg_logger, debug, alert_id)

# Configure Helix Control-M AAPI client



# If the alert is about a job
alert_is_job = False
if(alert[keywords_json['runId']] != '00000'):
    alert_is_job = True
    job_log = \
        f"*" * 70 + NL + \
        f"Job log for {alert[keywords_json['jobName']]} OrderID: {alert[keywords_json['runId']]}" + NL+ \
        f"LOG includes all executions to this point (runcount: {alert[keywords_json['runNo']]}" + NL+ \
        f"NOTE: If ticket information is added to log, it is not shown here."+ NL+ \
        f"*" * 70 + NL

    job_output = \
        f"*" * 70 + NL + \
        f"" + NL+ \
        f"Job output for {alert[keywords_json['jobName']]} OrderID: {alert[keywords_json['runId']]}:" \
            f"{alert[keywords_json['runNo']]}" + NL+ \
        f"" + NL+ \
        f"*" * 70 + NL

    try:
        status = dbg_assign_var(monitor.get_statuses(
            filter={"jobid": f"{alert[keywords_json['server']]}:{alert[keywords_json['runId']]}"}), "Status of job", dbg_logger, debug, alert_id)
        folder = status.statuses[0].folder
        order_date = status.statuses[0].order_date

    except TypeError as e:
            folder= "No status found to derive folder"
            order_date = "No status found to derive order date"

#Order date has been simplified for this example. The orderDate should be taken from the job and not the first status.
# https://stackoverflow.com/questions/7079241/python-get-a-dict-from-a-list-based-on-something-inside-the-dict

tkt_comments =  \
            f"Agent Name                  : {alert[keywords_json['host']]} {NL}" + \
            f"Folder Name                 : {folder} {NL}" + \
            f"Job Name                    : {alert[keywords_json['jobName']]} {NL}" + \
            f"Order ID                    : {alert[keywords_json['runId']]} {NL}" + \
            f"Run number                  : {alert[keywords_json['runNo']]} {NL}" + \
            f"Order Date                  : {order_date} {NL} {NL}" + \
            f"Ticket Notes                : {alert[keywords_json['notes']]} {NL} {NL}" + \
            f"Job Output and Log are attached  {NL} {NL}" + \
            f"The job can be seen on the {'Helix' if ctm_is_helix else ''} " + \
            f"Control-M Self Service site. Click the link below. {NL}" + \
            f"{NL}" + \
            f"https://{ctmweb}/ControlM/#Neighborhood:id={alert[keywords_json['runId']]}&ctm={alert[keywords_json['server']]}&name={alert[keywords_json['jobName']]}"+ \
            f"&date={order_date}&direction=3&radius=3" + \
            f"{NL}{NL}" if alert_is_job else "This alert is not job related"

tkt_work_notes = f"Ticket created automatically by {'Helix' if ctm_is_helix else ''} Control-M via Restful API" + \
    (f" for {alert[keywords_json['server']]}:{alert[keywords_json['runId']]}::{alert[keywords_json['runNo']]}" if alert_is_job else f"alert: {alert_id}")

values = {
        "z1D_Action":"CREATE",
        "Last_Name":"Allbrook",
        "First_Name":"Allen",
        "Description":  tkt_short_description,
        "Impact": tkt_impact,
        "Urgency": "1-Critical",
        "Reported Source": "Other",
        "Submitter": "Allen",
        "Service_Type": "User Service Restoration",
        "Company": "Calbro Services",
        "Categorization Tier 1":"Applications",
        "Categorization Tier 2":"Help Desk",
        "Categorization Tier 3":"Incident",
        "Product Model/Version":"2.2",
        "z1D_Details": tkt_work_notes,
        "z1D_WorklogDetails": f"Added from {'Helix ' if ctm_is_helix else ''}Control-M via REST API",
        "z1D_View_Access": "Public",
        "z1D_Secure_Log": "Yes",
        "z1D_Activity_Type": "Incident Task/Action"
    }


        # "Product Categorization Tier 1":"Software",
        # "Product Categorization Tier 2":"Software Application/System",
        # "Product Categorization Tier 3":"Job Scheduling Tools",
        # "Product Name": f"BMC {'Helix ' if ctm_is_helix else ''}CONTROL-M",

FORM_NAME = "HPD:IncidentInterface_Create"
RETURN_VALUES = ["Incident Number", "Request ID"]

debug = True

incident, status_code = itsm_client.create_form_entry(FORM_NAME, values, return_values=RETURN_VALUES)
incident_id = dbg_assign_var(incident["values"]["Incident Number"], "Incident ID Created", dbg_logger, debug, alert_id)
request_id = incident["values"]["Request ID"]

#Add comments to case worklog
updated_incident, status_code = itsm_client.add_worklog_to_incident(incident_id, tkt_comments)

tkt_provenance = f"Ticket sent from {getfqdn()}. Entry ID: {updated_incident['values']['Entry ID']}"

updated_incident, status_code = itsm_client.add_worklog_to_incident(incident_id, tkt_provenance)


# Load AAPI variables and create workflow object if need to attach logs
if ctmattachlogs and alert_is_job:
    log = dbg_assign_var(monitor.get_log(f"{alert[keywords_json['server']]}:{alert[keywords_json['runId']]}"), "Log of Job", dbg_logger, debug, alert_id)
    job_log = (job_log + NL + log)

    output = dbg_assign_var(monitor.get_output(f"{alert[keywords_json['server']]}:{alert[keywords_json['runId']]}",
            run_no=alert[keywords_json['runNo']]), "Output of job", dbg_logger, debug, alert_id)

    if output is None :
        output = (job_output + NL +  f"*" * 70 + NL +
                    "NO OUTPUT AVAILABLE FOR THIS JOB" + NL + f"*" * 70 )
    job_output = (job_output + NL +  output)

    file_log = f"log_{alert[keywords_json['runId']]}_{alert[keywords_json['runNo']]}.txt"
    file_output = f"output_{alert[keywords_json['runId']]}_{alert[keywords_json['runNo']]}.txt"

    # Write log
    # Declare object to open temporary file for writing
    tmpdir = tempfile.gettempdir()
    file_name =tmpdir+os.sep+file_log
    fh = open(file_name,'w')
    # content = job_log.replace('\n', '\r\n')
    content = job_log
    try:
        # Print message before writing
        dbg_logger.debug(f'Write data to log file {file_name}')
        # Write data to the temporary file
        fh.write(content)
        # Close the file after writing
        fh.close()
        # Attach to Incident
        updated_incident, status_code = itsm_client.attach_file_to_incident(incident_id, filepath=tmpdir, filename=file_log,
                details=f"{'Helix ' if ctm_is_helix else ''} Control-M Log file")
    except Exception as ex:
        message = f"Exception type {type(ex).__name__} occurred. Arguments:\n{str(ex.args)}"
        dbg_logger.info(message)
        exitrc = 30
    finally:
        # Print a message before reading
        dbg_logger.debug("Log data section completed. Log may have been added to the ticket")

    os.remove(file_name)

    # Write output
    # Declare object to open temporary file for writing
    tmpdir = tempfile.gettempdir()
    file_name =tmpdir+os.sep+file_output
    fh = open(file_name,'w')
    # content = job_output.replace('\n', '\r\n')
    content = job_output
    try:
        # Print message before writing
        dbg_logger.debug(f'Write data to output file {file_name}')
        # Write data to the temporary file
        fh.write(content)
        # Close the file after writing
        fh.close()
        # Attach to Incident
        updated_incident, status_code = itsm_client.attach_file_to_incident(incident_id, filepath=tmpdir, filename=file_output,
                details=f"{'Helix ' if ctm_is_helix else ''} Control-M Output file")
    except Exception as ex:
        message = f"Exception type {type(ex).__name__} occurred. Arguments:\n{str(ex.args)}"
        dbg_logger.info(message)
        exitrc = 30
    finally:
        # Print a message before reading
        dbg_logger.debug("Output data section completed. Output may have been added to the ticket")

    os.remove(file_name)

itsm_client.release_token()

sys.exit(exitrc)
