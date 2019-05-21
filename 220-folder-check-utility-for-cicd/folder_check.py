import json
import sys
import requests
import urllib3
import argparse
from email.policy import default

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
    
    # Initializing variables
    # =================================================================================================
    
    input_file = ''
    current_deployDescriptor=None
    previous_revision_file = ''
    endpoint=''
    user=''
    password=''
    mode_str=''
    perform_delete=False
    perform_deploy=False
    auto_discover_server=False
    verbose=False
    
    # Parsing the command line parameter 
    # =================================================================================================
       
    parser = argparse.ArgumentParser(description='Checks if folders are deleted from a Control-M jobs-as-code file by comparing it with the previous version')
    
    parser.add_argument("-c" , "--current-revision", required=True, help="File that holds the current version of your Control-M job definition file" )
    parser.add_argument("-c_dd","--current-deploy-descriptor", required=False, help="File that holds the current deploy-descriptor definition file" )
    parser.add_argument("-o" , "--previous-revision", required=True, help="File that holds the previous version of your Control-M job definition file" )
    parser.add_argument("-o_dd","--previous-deploy-descriptor", required=False, help="File that holds the current deploy-descriptor definition file" )
    parser.add_argument("-m","--mode", required=False, default="test" , choices=['test', 'delete', 'delete+deploy'], help="Specifies to run this script in test mode or delete mode. Test mode will only print the folders to be deleted. " )
    parser.add_argument("-e","--endpoint", required=True, help="Control-M Automation API end-point for connecting with Control-M" )
    parser.add_argument("-u","--user", required=True, help="Control-M user name for connecting with Control-M" )
    parser.add_argument("-p","--password", required=True, help="Control-M password for connecting with Control-M" )
    parser.add_argument("--auto-discover-server", required=False, default=True, help="Toggles if the control-m server must be auto discovered if not specified in the job definition." )
    parser.add_argument("-v" , "--verbose", required=False,  action = "store_true", help="Enables verbose mode" )
    parser.add_argument('--version', action='version', version='Version: %(prog)s 1.0')
    
    parse_result = parser.parse_args()
    
    input_file                  = parse_result.current_revision
    current_deployDescriptor    = parse_result.current_deploy_descriptor
    previous_revision_file      = parse_result.previous_revision
    previous_deployDescriptor   = parse_result.previous_deploy_descriptor
    mode_str                    = parse_result.mode
    endpoint                    = parse_result.endpoint
    user                        = parse_result.user
    password                    = parse_result.password
    verbose                     = parse_result.verbose
    
    if mode_str == "delete": perform_delete = True
    if mode_str == "delete+deploy":
        perform_delete = True
        perform_deploy = True
    
    # =================================================================================================
    
    
    # Printing the input parameters
    # =================================================================================================
    
    if verbose:
        print()
        print ('Current revision file           :', input_file)
        print ('Current Deploy Descriptor file  :', current_deployDescriptor)
        print ('Previous revision file          :', previous_revision_file)
        print ('Previous Deploy Descriptor file :', previous_deployDescriptor)
        print ('Endpoint                        :', endpoint)
        print ('User                            :', user)
        print ('Password                        : *************'+ password[-2:]) 
        print ('Auto discover server            :', auto_discover_server)
    
    if mode_str == "delete":
        print( colors.fg.red + "\nRunning in delete mode" + colors.reset)
    elif mode_str == "delete+deploy":
        print( colors.fg.red + "\nRunning in delete and deploy mode" + colors.reset)
    else:
        print( colors.fg.orange  + "\nRunning in test mode" + colors.reset)    
    
    # =================================================================================================
    
    # Login to Control-M
    # =================================================================================================
    
    token = ctm_login(endpoint, user, password)
    
    # =================================================================================================
    
    # Getting the input files and transform if Deploy Descriptor parameter is provided
    # ================================================================================================= 
        
    if not current_deployDescriptor == None:
        current_json_data=transform(endpoint, token, input_file, current_deployDescriptor)
    else:
        current_json_data=open(input_file).read()
    
    current_version = json.loads(current_json_data)
    
    if not previous_deployDescriptor == None:
        previous_revision_json_data=transform(endpoint, token, input_file, previous_deployDescriptor)
    else:
        previous_revision_json_data=open(previous_revision_file).read()
    
    previous_revision = json.loads(previous_revision_json_data)

    # Build current and previous files
    
    print()
    
    if current_deployDescriptor == None: 
        print("Build current revision file "+input_file)
        build_file(endpoint, token, input_file)
    else:
        print("Build current revision file "+input_file +" using deploy descriptor " + current_deployDescriptor)
        build_file(endpoint, token, input_file, current_deployDescriptor)
    
    if previous_deployDescriptor == None: 
        print("Build previous revision file "+previous_revision_file)
        build_file(endpoint, token, previous_revision_file)
    else:
        print("Build previous revision file "+previous_revision_file +" using deploy descriptor " + previous_deployDescriptor)
        build_file(endpoint, token, previous_revision_file, previous_deployDescriptor)

    print ()
                
    # =================================================================================================
    
    # Get current folders from file
    # =================================================================================================
        
    current_folders = get_folders(current_version)
    previous_revision_folders = get_folders(previous_revision)

    single_ctmserver_on_em = "" 
    for k, v in current_folders.items():
        if v == None:
            if auto_discover_server:
                if single_ctmserver_on_em == "":
                    single_ctmserver_on_em=get_servers(endpoint, token)
                current_folders[k]=single_ctmserver_on_em
            else:    
                current_folders[k]="None"
    for k, v in previous_revision_folders.items():
        if v == None:
            if auto_discover_server:
                if single_ctmserver_on_em == "":
                    single_ctmserver_on_em=get_servers(endpoint, token)
                previous_revision_folders[k]=single_ctmserver_on_em
            else:    
                current_folders[k]="None"
    
    # =================================================================================================
  
    # =================================================================================================
    
    # Evaluating the difference and print on screen 
    # =================================================================================================
    
    # Set variables to control printing the table with the differences 

    column_divider = "|"
    column1_string =  " FOLDER NAME " 
    column2_string = " SERVER NAME "
    column3_string = " DIFFERENCE "

    column1_width = 60
    column2_width = 40
    column3_width = len(column3_string)+5
    
    # Print table header
    
    print(" " + "-" * (column1_width+column2_width+column3_width-1))
    print(column_divider + colors.bold +column1_string + colors.reset +" "*(column1_width-len(column_divider+column1_string))+column_divider + colors.bold + column2_string + colors.reset +" "*(column2_width-len(column_divider+column2_string))+ colors.bold + column_divider+column3_string + colors.reset + " "*(column3_width-len(column_divider+column3_string))+column_divider)        
    print(" " + "-" * (column1_width+column2_width+column3_width-1))    
    
    # Determine the differences
    
    removed = set(previous_revision_folders.items()) - set(current_folders.items())
    added = set(current_folders.items()) - set(previous_revision_folders.items())
    equal = set(previous_revision_folders.items()) & set(current_folders.items())
    
    # Print the differences in the table
    
    for k, v in equal: 
        print(column_divider, k , " "*(column1_width-len(column_divider+k)-3), column_divider, v, " "*(column2_width-len(column_divider+v)-3), column_divider, "Exists in both", " "*(column3_width-len(column_divider+"Exists in both")-3)+column_divider)    
        
    for k, v in added: 
        print(column_divider, colors.fg.green + k + colors.reset, " "*(column1_width-len(column_divider+k)-3), column_divider, colors.fg.green + v  + colors.reset, " "*(column2_width-len(column_divider+v)-3), column_divider, colors.fg.green + "Added" + colors.reset, " "*(column3_width-len(column_divider+"Added")-3),column_divider)    
           
    for k, v in removed: 
        print(column_divider, colors.fg.red + k + colors.reset , " "*(column1_width-len(column_divider+k)-3), column_divider, colors.fg.red + v + colors.reset, " "*(column2_width-len(column_divider+v)-3), column_divider, colors.fg.red + "Removed" + colors.reset, " "*(column3_width-len(column_divider+"Removed")-3),column_divider)    

   
    # Print table footer

    print(" " + "-" * (column1_width+column2_width+column3_width-1))
    if not perform_delete: print("\nRun with '-m delete' option to perform an delete on of the folder on the Control-M environment in above table")
    
    # =================================================================================================
    
        
    # Deploy current revision
    # =================================================================================================
    
    print()
    
    if perform_deploy:
        if current_deployDescriptor == None: 
            print("Deploy current revision file "+input_file)
            deploy_file(endpoint, token, input_file)
        else:
            print("Deploy current revision file "+input_file +" using deploy descriptor " + current_deployDescriptor)
            deploy_file(endpoint, token, input_file, current_deployDescriptor)
    # Delete folders
    # =================================================================================================
    
    print()
    if perform_delete:
        if len(removed)>0:
            print("Performing delete:")
            for k, v in removed:
                delete_folders(k, v, endpoint, token)
        else:
            print("Nothing to be deleted")
    
    # =================================================================================================
    
    # Logout 
    # =================================================================================================
    
    ctm_logout(endpoint, token)
    
    # =================================================================================================
    
def get_folders(json_input):
    
    # Setting variables
    # =================================================================================================
    
    ctm_server_from_defaults = json_input['Defaults'].get("ControlmServer")
    elements = {}
    
    # =================================================================================================
    
    # Loop over json_input to extract elements of given type
    # =================================================================================================
    
    for element in json_input: 
        try:
            if json_input[element]['Type'] == "Folder" or json_input[element]['Type'] == "SimpleFolder":
                # Get the server for the folder
                elements[element] = json_input[element].get('ControlmServer')

                # Get the server from defaults if not specified on the folder level
                if elements[element] == None: 
                    if ctm_server_from_defaults: elements[element] = ctm_server_from_defaults
                    
        except (ValueError, KeyError, TypeError):
            # Some elements don't have a type (e.g. defaults). We ignore these
            ignore=""
    
    # =================================================================================================
    
    return elements

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

def delete_folders(folder_name, ctmserver, endpoint, token):
    
    # Build URL and header
    # =================================================================================================
    url = endpoint + "/deploy/folder/" + ctmserver + "/" + folder_name
    headers = json.loads('{"Authorization": "Bearer ' + token + '"}')
    # =================================================================================================
    
    # Perform REST call and get the response
    # =================================================================================================

    response = requests.request("DELETE", url, headers=headers, verify=False)

    # =================================================================================================    
    
    if response.ok:
        print(colors.fg.green+ "Folders successfully deleted:")
        print(colors.fg.green+ response.text + colors.reset)   
    else:
        print(colors.fg.red+ "Error while trying to delete folder "+folder_name+" on server "+ctmserver)
        print(colors.fg.red+ response.text + colors.reset)
    
def get_servers(endpoint,token):
    
    # Auto discover ctm server from Control-M Enterprise Manager.
    
    # Build header
    # =================================================================================================
    
    servers = {}
    url = endpoint+"/config/servers/"
    headers = json.loads('{"Authorization": "Bearer ' + token + '"}')
    
    # =================================================================================================
    
    # Perform REST call and get response
    # =================================================================================================
    
    response = requests.request("GET", url, headers=headers, verify=False)
    servers=json.loads(response.text)
    
    # =================================================================================================
    
    # Return ctm server if only 1 is returned. Throw an error if there are more than one 
    # =================================================================================================
    
    if len(servers)>1: 
        print("ERROR: Control-M Enterprise Manager has more than one server. Cannot determine default")
        sys.exit()
    else:
        return servers[0]['name']
    
    # =================================================================================================

def build_file(endpoint, token, definition_file, deploydescriptor_file="" ):
    
    # Login to CTM endpoint and build file
    
    # Build URL and header 
    # =================================================================================================
    
    url = endpoint+"/build"
    
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
    
    #exit(r.status_code == requests.codes.ok)

    
    if response.ok:
        print(colors.fg.green+ "Build successful!"+ colors.reset)
        #print(colors.fg.green+ response.text + colors.reset)   
    else:
        print(colors.fg.red+ "Error while building"+ colors.reset)
        print(colors.fg.red+ response.text + colors.reset)
        sys.exit()

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
        print(colors.fg.green+ "Transform of "+definition_file+" successful")
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

