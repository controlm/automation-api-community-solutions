# Scripts and Documentation

The [search_profiles.py](./search_profiles.py) retrieves specified connection profiles from Control-M/Agents and the results are displayed in JSON format.
The tool allows specifying pairs of key/value attributes for the search criteria so only connection profiles with matches are displayed.  Currently, an *OR* of the matches
is performed.  No *AND* support yet.

When no key/value pairs are specified all connection profiles for a particular type are returned.  This is useful for retrieving all the connection profiles for a Control-M/Agent.

A single Control-M data center is searched for each execution.  For multiple data centers execute script for each data center.

## Known Issues and Workarounds
* The key and value parameter must match exactly alpahnumerically.  Partial or wildcard matches are not implemented.  
    * use case insenstive match with the *-i* switch.
    * use no key/value pairs to get all results and search with *grep* or *find*
This directory contains 6 Python scripts:
* The key/value pair will not match boolean values such as *"VerifyBytes": true,* but will match *"VerifyBytes": "true",* since both are strings.
    * use case insenstive match with the *-i* switch
    * The following won't match:  -key "VerifyBytes" -value true
    * But the following will:  -key "VerifyBytes" -value true -i
* Not all attributes are supported for all connections profile types.  In these cases the search will return an error for Control-M/Agent and the remaining profiles can not be retrieved.
    * some attributes can be removed to allow the profile retrieval to continue
    * apply the latest Automation API version
## Content
This directory contains 6 Python scripts.

|  Name | Description | Documentation |
|-------|-------------| ------------- |
|[search_aapi.py](./search_aapi.py)| Automation API calls    |[search_aapi.md](./search_aapi.md)   |           
|[search_global.py](./search_global.py)| Global values used for debug, ingnoring case, ignoring erors|[search_global.md](./search_global.md)|
|[search_menu.py](./search_menu.py)| usage menu display|[search_menu.md](./search_menu.md)|
|[search_parse.py](./search_parse.py)| functions to search and key/pair searches|[search_parse.md](./search_parse.md)|
|[search_profiles.py](./search_profiles.py)| main|[search_profiles.md](./search_profiles.md)|
|[search_tools.py](./search_tools.py)| basic tools - implements color on supported terminals|[search_tools.md](./search_tools.md)|




The main script is [search_profiles.py](./search_profiles.py) and is the only one that shoud be executed directly.  The remaining files contain Python functions and methods used by the tool.
The script demonstrates using Python 2 or 3 to retrieve connection profiles using Automation API.  The Python code handles the searching and matching of search keys and values.

The tool requires httplib2 for Python.  It's a common library that can be installed using *pip* on various implementations of Python.
```
For example:
   pip install httplib2
```

## How to Install
Copy all files with .py extension to the same folder or directory.


## How to Run
```
search_profiles.py [required parameters] [options]

```
## [required parameters]
```
-endpoint ENDPOINT                     Automation API endpoint eg https://wla919:8443/automation-api
-u USERNAME                            EM user credentials
-p PASSWORD
-ctm DATACENTER                        data center name
                                       no wildcard support
-agent AGENT                           to specify all agents use ALL or '*'
                                       wildcard supported eg 'dev_*'

```
## [options]
```
-debug [1|2|3]
-i                                      case insensitive match
-c                                      pretty/color mode
-s                                      suppress errors messages
-key string -value string               multiple key/value pairs supported
                                        results are returned for any key/value match
                                        eg -key Host -value localhost -key Username -value root

```
## Example Outputs:
Search for User *BATCH* in SAP connection profiles.
```
./search_profiles.py -endpoint https://wla919:8443/automation-api -u devops -p devopspassword -ctm wla919 -agent wla919 -type SAP -key User -value BATCH
{
   "results": [
      [
         {
            "BATCH": {
               "Type": "ConnectionProfile:SAP",
               "User": "BATCH",
               "AppVersion": "BW 3.<X> or later",
               "Password": "*****",
               "SapClient": "200",
               "UseExtended": true,
               "SapResponseTimeOut": "360",
               "TargetAgent": "wla919",
               "TargetCTM": "wla919",
               "ApplicationServerLogon": {
                  "SystemNumber": "10",
                  "Host": "locahost"
               }
            }
         }
      ]
   ]
}

```
Search for Hostname *star* or *square* found in single or dual endpoint FileTransfer profiles.
```
 ./search_profiles.py -endpoint https://wla919:8443/automation-api -u devops -p devopspassword -ctm wla919 -agent wla919 -type FileTransfer -key HostName -value star -key HostName -value square
 {
   "results": [
      [
         {
            "star": {
               "Type": "ConnectionProfile:FileTransfer:FTP",
               "WorkloadAutomationUsers": [
                  "emuser"
               ],
               "VerifyBytes": true,
               "User": "controlm",
               "Passive": "noSubstituteIP",
               "HostName": "star",
               "Password": "*****",
               "HomeDirectory": "/space/controlm/",
               "TargetAgent": "wla919",
               "TargetCTM": "wla919"
            }
         }
      ],
      [
         {
            "square_ftp": {
               "Type": "ConnectionProfile:FileTransfer:FTP",
               "WorkloadAutomationUsers": [
                  "emuser",
                  "reportuser",
                  "sapadmin"
               ],
               "VerifyBytes": true,
               "User": "controlm",
               "Passive": "noSubstituteIP",
               "HostName": "square",
               "Password": "*****",
               "HomeDirectory": "/space/controlm/",
               "TargetAgent": "wla918",
               "TargetCTM": "wla919"
            }
         }
      ],
      [
         {
            "star_to_square": {
               "Type": "ConnectionProfile:FileTransfer:DualEndPoint",
               "WorkloadAutomationUsers": [
                  "emuser"
               ],
               "VerifyBytes": true,
               "TargetAgent": "wla919",
               "TargetCTM": "wla919",
               "Endpoint:Src:SFTP_0": {
                  "Type": "Endpoint:Src:SFTP",
                  "User": "controlm",
                  "HostName": "star",
                  "Password": "*****",
                  "HomeDirectory": "/space/controlm/"
               },
               "Endpoint:Dest:SFTP_1": {
                  "Type": "Endpoint:Dest:SFTP",
                  "User": "controlm",
                  "HostName": "square",
                  "Password": "*****",
                  "HomeDirectory": "/space/controlm/"
               }
            }
         }
      ]
   ]
}
```

## Table of Contents
* [Main README](../README.md)
* Additional Documentation:
    * [search_aapi.py](search_aapi.md)
    * [search_global.py](search_global.md)
    * [search_menu.py](search_menu.md)
    * [search_parse.py](search_parse.md)
    * [search_profiles.py](search_profiles.md)
    * [search_tools.py](search_tools.md)

