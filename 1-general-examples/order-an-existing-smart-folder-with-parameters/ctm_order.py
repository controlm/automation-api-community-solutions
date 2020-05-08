import json
import sys
import requests
import urllib3
import argparse
from email.policy import default

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# AUTHOR: Tijs Monté (email tijs_monte@bmc.com)
# VERSION 1.0

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
    
    # Initializing variables
    # ================================================================================================
    
    endpoint=''
    ctm_server=''
    user=''
    password=''
    folder=''
    jobs=''
    config_file=''
    verbose=False
    configuration=''
    
    # Parsing the command line parameter 
    # =================================================================================================
       
    parser = argparse.ArgumentParser(description='Orders an adhoc job in Control-M for the folder specified')
   
    parser.add_argument("-e","--endpoint", required=True, help="Control-M Automation API end-point for connecting with Control-M" )
    parser.add_argument("-s", "--ctm_server", required=True, help="Control-M Server name")
    parser.add_argument("-u","--user", required=True, help="Control-M user name for connecting with Control-M" )
    parser.add_argument("-p","--password", required=True, help="Control-M password for connecting with Control-M" )
    parser.add_argument("--folder", required=True, help="Control-M folder name which holds the jobs to be ordered")
    parser.add_argument("--jobs", required=False, help="Control-M jobs to be ordered from the specified folder")
    parser.add_argument("--config_file", "-f", required =False, help="A json file that holds additional configuration parameters" )
    parser.add_argument("-v" , "--verbose", required=False,  action = "store_true", help="Enables verbose mode" )    
    parser.add_argument('--version', action='version', version='Version: %(prog)s 1.1')
    
    parse_result = parser.parse_args()

    endpoint    = parse_result.endpoint
    ctm_server  = parse_result.ctm_server
    user        = parse_result.user
    password    = parse_result.password 
    folder      = parse_result.folder
    jobs      = parse_result.jobs
    config_file = parse_result.config_file
    verbose     = parse_result.verbose
    
    if verbose:
        print("Perform CTM login with:")
        print("Endpoint: ", endpoint)
        print("User: ", user)
        print("Password: **********")
        print()
    
    token = ctm_login(endpoint, user, password)
    if verbose:
        print("Token:", token)
        print()
        print("Ordering folder")
    
    config_data={}
    
    if config_file:
        with open(config_file) as config:
            data = config.read()
            config_data = json.loads(data)
    
    if verbose and config_data:
        print("Using additional config from file "+ config_file + ":")
        print(config_data)
        
    result = order_folder(endpoint, token, folder, jobs, ctm_server, configuration, config_data, verbose)
    
    if verbose:
        print("Response:", result.text)
    
    if verbose:
        print()
        print("Perform CTM logout with:")
        print("Endpoint: ", endpoint)
        print("token: ", token)
    
    ctm_logout(endpoint, token)
    
    if result.status_code == 200:
        print(colors.fg.green+"Folder successfully ordered:"+ colors.reset)
        print(result.text)
        sys.exit(0)
    else:
        sys.exit(1)

def order_folder(endpoint, token, folder, jobs, ctm_server, configuration, config={}, verbose=False):
    
    # Login to CTM endpoint and deploy file
    
    # Build URL and header 
    # =================================================================================================
    
    url = endpoint+"/run/order"
    payload=config
    payload["ctm"] = ctm_server
    payload["folder"] = folder
    payload["jobs"] = jobs
    # payload = config
    if verbose:
        print()
        print("Payload for ordering the jobs:")
        print(payload)
        print()
    
    response = requests.post(url, data=json.dumps(payload), headers={'Content-Type': "application/json",'Authorization': 'Bearer ' + token}, verify=False)
    
    if response.ok:
        if verbose:
            print(colors.fg.green+ "Folder ordered"+ colors.reset)
           
    else:
        print(colors.fg.red+ "Error while ordering"+ colors.reset)
        print(colors.fg.red+ response.text + colors.reset)
        sys.exit() 

    return response

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
