import json
import sys
import os
import requests
import urllib3
import argparse
from email.policy import default
from pip._internal.cli.cmdoptions import verbose

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class colors: 
    
    # Class to hold color definition used for printing
    # =================================================================================================
    reset='\033[0m'
    bold='\033[01m'
    disable='\033[02m'
    underline='\033[04m'
    reverse='\033[07m'
    strikethrough='\033[09m'
    invisible='\033[08m'
    class fg: 
        black='\033[30m'
        red='\033[31m'
        green='\033[32m'
        orange='\033[33m'
        blue='\033[34m'
        purple='\033[35m'
        cyan='\033[36m'
        lightgrey='\033[37m'
        darkgrey='\033[90m'
        lightred='\033[91m'
        lightgreen='\033[92m'
        yellow='\033[93m'
        lightblue='\033[94m'
        pink='\033[95m'
        lightcyan='\033[96m'
    class bg: 
        black='\033[40m'
        red='\033[41m'
        green='\033[42m'
        orange='\033[43m'
        blue='\033[44m'
        purple='\033[45m'
        cyan='\033[46m'
        lightgrey='\033[47m'

    # =================================================================================================

def main(argv):
    
    # =================================================================================================
    # Initializing variables
    # =================================================================================================
    
    input_file = ''
    deployDescriptor=None
    endpoint=''
    user=''
    password=''
    password_masked = ''
    mode_str=''
    config_file=''
    perform_deploy=False
    verbose=False
    output_file_name=''
    token=''
    
    # =================================================================================================
    # Parsing the command line parameters
    # =================================================================================================
       
    parser = argparse.ArgumentParser(description='Checks if folders are deleted from a Control-M jobs-as-code file by comparing it with the previous version')
    
    parser.add_argument("-j" , "--json-file", required=True, help="File that holds the Control-M jobs-as-code definition file" )
    parser.add_argument("-dd","--deploy-descriptor", required=False, help="File that holds the deploy-descriptor definition file" )
    parser.add_argument("-m","--mode", required=False, default="filter" , choices=['filter', 'deploy'], help="Specifies to run this script in filter only mode or deploy mode. Filter mode will only print the filtered content. " )
    parser.add_argument("-e","--endpoint", required=False, help="Control-M Automation API end-point for connecting with Control-M in deploy mode" )
    parser.add_argument("-u","--user", required=False, help="Control-M user name for connecting with Control-M in deploy mode" )
    parser.add_argument("-p","--password", required=False, help="Control-M password for connecting with Control-M in deploy mode" )
    parser.add_argument("-c","--config-file", required=False, help="JSON Config file with list of allowed agents" )
    parser.add_argument("-v" , "--verbose", required=False,  action = "store_true", help="Enables verbose mode" )
    parser.add_argument('--version', action='version', version='Version: %(prog)s 1.0')
    
    parse_result = parser.parse_args()
    
    input_file                  = parse_result.json_file
    deployDescriptor    = parse_result.deploy_descriptor
    mode_str                    = parse_result.mode
    endpoint                    = parse_result.endpoint
    user                        = parse_result.user
    password                    = parse_result.password
    verbose                     = parse_result.verbose
    config_file                 = parse_result.config_file
        
    
    if verbose : print("Checking mode. Taking input value:" , mode_str)
    if mode_str == "deploy": perform_deploy = True
    if verbose : print("Set deploy to", perform_deploy)
    
    if config_file:
        if verbose: print("Reading config file")
        config_file=json.loads(open(config_file).read())
        if verbose: print("Config file data:", config_file["allowed_agents"])
    
    # =================================================================================================
    # Printing the input parameters in verbose mode
    # =================================================================================================
    
    if verbose and mode_str == "filter": 
        print ('Json file           :', input_file)
        print ('Deploy descriptor   :', deployDescriptor)
    
   
    if verbose and mode_str == "deploy": 
        if password:
            password_masked = '*************'+ password[-2:]
        print ('Json file           :', input_file)
        print ('Deploy descriptor   :', deployDescriptor)
        print ('Endpoint            :', endpoint)
        print ('User                :', user)
        print ('Password            :', password_masked) 
    
    
    if mode_str == "deploy" and verbose:
        print( "\nRunning in deploy mode")
    
    if mode_str == "filter" and verbose:
        print( "\nRunning in filter only mode." )
    
    # =================================================================================================
    # Check if credentials are provided if needed
    # =================================================================================================
    
    if mode_str == "deploy" or deployDescriptor :
        if not endpoint or not user or not password:
            print("\nERROR: Credentials not specified. Please provide endpoint, user name and password information in deploy mode or when using a deployDescriptor file")
            sys.exit(1)
    
    # =================================================================================================
    # Login to Control-M if needed
    # =================================================================================================

    if perform_deploy or deployDescriptor:
        if verbose: print("Getting token")
        token = ctm_login(endpoint, user, password)
    
    # =================================================================================================
    # Getting the input files and transform if Deploy Descriptor parameter is provided
    # ================================================================================================= 
            
    if deployDescriptor and token:
        if verbose: print("Transforming input file")
        json_data=transform(endpoint, token, input_file, deployDescriptor)
    else:
        json_data=open(input_file).read()

    # =================================================================================================
    # Filter connection profile out of json and filter on allowed agents if provided 
    # ================================================================================================= 
 
    if config_file:
        conn_profiles = get_connection_profiles(json.loads(json_data), config_file["allowed_agents"])
    else:
        conn_profiles = get_connection_profiles(json.loads(json_data))
 
    # =================================================================================================
    # Write filtered and if specified transformed connection profile to temp file for deployment  
    # ================================================================================================= 
    
    if token and perform_deploy: 
        output_file_name = '{}.json'.format(token)
        if verbose: print("Creating temporay connection profile json file:", output_file_name)
        with open(output_file_name, 'a') as output_file:
            json.dump(conn_profiles, output_file)
    
    # =================================================================================================
    # Deploy connection profile when in deploy mode  
    # ================================================================================================= 
        
    if token and perform_deploy:
        deploy_file(endpoint, token, output_file_name)
    
    # =================================================================================================
    # Print filtered and if specified transformed connection profile to console
    # ================================================================================================= 
        
    print(json.dumps(conn_profiles, indent=4))
    
    # =================================================================================================
    # Clean-up temp file used for deployment  
    # ================================================================================================= 
        
    if output_file_name: 
        if verbose: print("Removing temporary connection profile json file:", output_file_name )
        os.remove(output_file_name)

    # =================================================================================================
    # Logout 
    # =================================================================================================
    
    if token: ctm_logout(endpoint, token)
    
    # =================================================================================================
    
def get_connection_profiles(json_input, allowed_agents=""):
    
    # =================================================================================================
    # Setting variables
    # =================================================================================================
    
    elements = {}
    
    # =================================================================================================
    # Loop over json_input to extract elements of given type
    # =================================================================================================
    
    for element in json_input: 
        try: 
            if json_input[element]['Type'][0:17]=="ConnectionProfile" and (json_input[element]["TargetAgent"] in allowed_agents or not allowed_agents):
                elements[element]=json_input[element]
        except (ValueError, KeyError, TypeError):
            # Some elements don't have a type (e.g. defaults). We ignore these.
            ignore=""
        
    
    return dict(elements)

def ctm_login(endpoint, user, password):
    
    # Login to CTM endpoint and return token
    
    # Build URL and token
    # =================================================================================================
    
    url = endpoint + "/session/login"
    payload = "{\"username\": \"" + user + "\", \"password\": \"" + password+ "\"}"
    headers = {
        'Content-Type': "application/json",
        'cache-control': "no-cache"
        }
    
    # =================================================================================================
    
    # Perform REST call and get token
    # =================================================================================================
    
    response = requests.request("POST", url, data=payload, headers=headers, verify=False)
    token = json.loads(response.text)
    
    # =================================================================================================
    
    # Evaluate token and return 
    # =================================================================================================
    
    try:
        return token['token']
    except (ValueError, KeyError, TypeError):
        print("Error while trying to login:\n"+ response.text)
        sys.exit()
    return token['token']

    # =================================================================================================


def deploy_file(endpoint, token, definition_file, deploydescriptor_file="" ):
    
    # Login to CTM endpoint and deploy file
    
    # Build URL and header 
    # =================================================================================================
    
    url = endpoint+"/deploy"
    
    if deploydescriptor_file == "":
        uploaded_files = [
            ('definitionsFile', (definition_file, open(definition_file, 'rb'), 'application/json'))
            ]
    else:
        uploaded_files = [
            ('definitionsFile', (definition_file, open(definition_file, 'rb'), 'application/json')),
            ('deployDescriptorFile', (deploydescriptor_file, open(deploydescriptor_file, 'rb'), 'application/json'))
            ]
 
    response = requests.post(url, files=uploaded_files, headers={'Authorization': 'Bearer ' + token}, verify=False)
    
    if response.ok:
        print(colors.fg.green+ "Deploy successful!"+ colors.reset)
        #print(colors.fg.green+ response.text + colors.reset)   
    else:
        print(colors.fg.red+ "Error while deploying"+ colors.reset)
        print(colors.fg.red+ response.text + colors.reset)
        sys.exit()

def transform(endpoint, token, definition_file, deploydescriptor_file ):
    
    # Login to CTM endpoint and transform file
    
    # Build URL and header 
    # =================================================================================================
    
    url = endpoint+"/deploy/transform"
    
    if deploydescriptor_file == "":
        uploaded_files = [
            ('definitionsFile', (definition_file, open(definition_file, 'rb'), 'application/json'))
            ]
    else:
        uploaded_files = [
            ('definitionsFile', (definition_file, open(definition_file, 'rb'), 'application/json')),
            ('deployDescriptorFile', (deploydescriptor_file, open(deploydescriptor_file, 'rb'), 'application/json'))
            ]
 
    response = requests.post(url, files=uploaded_files, headers={'Authorization': 'Bearer ' + token}, verify=False)
    
    if response.ok:
        return response.text 
    else:
        print(colors.fg.red+ "Error while transforming "+definition_file)
        print(colors.fg.red+ response.text + colors.reset)
        sys.exit()
        
def ctm_logout(endpoint, token):
    
    # Login to CTM endpoint and return token
    
    # Build URL and header 
    # =================================================================================================
    
    url = endpoint+"/session/logout"
    payload = ""
    querystring=json.loads('{"token" : "' + token + '"}')
    headers = {
        'Content-Type': "application/json",
        'cache-control': "no-cache"
        }
    
    # =================================================================================================
    
    # Perform REST call to logout 
    # =================================================================================================
    
    response = requests.request("POST", url, data=payload, headers=headers, params=querystring, verify=False)
    token = json.loads(response.text)
    
    
    # =================================================================================================

if __name__ == "__main__":
    main(sys.argv[1:])

