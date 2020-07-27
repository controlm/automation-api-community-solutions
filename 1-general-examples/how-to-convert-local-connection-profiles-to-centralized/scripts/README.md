# lcps_to_ccps.py

## Usage
```
Usage: lcps_to_ccps.py [-h] -u USERNAME -p PASSWORD -c CTM -a AGENT -t TYPE [-i]

Conversion of local connection profiles to centralized connection profiles

optional arguments:
  -h, --help            show this help message and exit
  -u USERNAME, --username USERNAME
                        Username for login to Control-M/Enterprise Manager
  -p PASSWORD, --password PASSWORD
                        Password for login to Control-M/Enterprise Manager
  -c CTM, --ctm CTM     Name of Control-M/Server
  -a AGENT, --agent AGENT
                        Name of host or alias of the Control-M/Agent
  -t TYPE, --type TYPE  Type of local connection profiles. You can choose from the following types of connection profiles: AWS,
                        ApplicationIntegrator:SISnet, Azure, Database, FileTransfer, Hadoop, Informatica, SAP
  -i, --insecure        Disable TLS certificate verification
```

Example of running:
```
./lcps_to_ccps.py -u USER -p PASS -c SERVER -a AGENT -i -t Database
```

The output should look similar to the following:
```
User "USER" logged-in

Step 1 - Gets a list of local connection profiles by type "Database" from Control-M:
----------
2 Local connection profiles were found

Step 2 - Converts local connection profiles of type "Database" to centralized connection profiles:
----------
2 Local connection profiles were converted

Step 3 - Writes the converted list of centralized connection profiles in a temporary json file:
----------
temp.json file is ready! *** PLEASE REVIEW IT'S CONTENT ***

Step 4 - Builds (that is, validates) the converted list of centralized connection profiles:
----------
Build result:
[ {
  "deploymentFile" : "temp.json",
  "successfulFoldersCount" : 0,
  "successfulSmartFoldersCount" : 0,
  "successfulSubFoldersCount" : 0,
  "successfulJobsCount" : 0,
  "successfulConnectionProfilesCount" : 2,
  "successfulDriversCount" : 0,
  "isDeployDescriptorValid" : false
} ]

Before you continue, please review the temp.json file...
Do you want to deploy centralized connection profiles to Control-M (Y/N)? y

Step 5 (Optional) - Deploys validated centralized connection profiles to Control-M.
----------
Deploy result:
[ {
  "deploymentFile" : "temp.json",
  "successfulFoldersCount" : 0,
  "successfulSmartFoldersCount" : 0,
  "successfulSubFoldersCount" : 0,
  "successfulJobsCount" : 0,
  "successfulConnectionProfilesCount" : 2,
  "successfulDriversCount" : 0,
  "isDeployDescriptorValid" : false,
  "deployedConnectionProfiles" : [ "FOR_DEL", "FOR_DEL2" ]
} ]

User "USER" logged-out

Done
```

## Temp file
The script writes a temp file, which contains the converted list of centralized connection profiles. For example, the above run creates the following file:
```
{
    "FOR_DEL": {
        "Type": "ConnectionProfile:Database:Oracle:ConnectionString",
        "User": "USER",
		    "ConnectionString": "CONNECTION:1521:ORCL",
        "Password": { "Secret": "for_del_secret" }
        "Centralized": true
    },
    "FOR_DEL2": {
        "Type": "ConnectionProfile:Database:Oracle:ConnectionString",
        "User": "USER",
		    "ConnectionString": "CONNECTION:1521:ORCL",
        "Password": { "Secret": "for_del2_secret" }
        "Centralized": true
    }
}
```

## Log file
The script writes a log file.

## Important Notes
* When getting connection profiles from Control-M, all password definitions are hidden. You MUST replace all hidden passwords with real passwords or secrets. 
* In the script, all passwords are specified as secrets.