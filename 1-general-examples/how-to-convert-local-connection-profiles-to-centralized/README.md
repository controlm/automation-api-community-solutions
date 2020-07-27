# Conversion of local connection profiles to centralized connection profiles
Connection profiles are used to define access methods and security credentials for a specific application. 
They can be referenced by multiple jobs. You must deploy the connection profile definition before running the relevant jobs.

There are two types of connection profiles:
1. Local connection profile - stored on a specific agent.
2. Centralized connection profile - stored in the Control-M database and available to all Control-M/Agents.
	
### Local connection profile definition
The following example shows how to define a local connection profile for an Oracle database using a connection string.
```
{
  "CONNECTION_STRING_NAME": {
    "Type": "ConnectionProfile:Database:Oracle:ConnectionString",
    "ConnectionString": "CONNECTION:1521:ORCL",
    "User": "USER",
    "Password": { "Secret": "SECRET_NAME" }
    "TargetCTM": "SERVER",
    "TargetAgent": "AGENT",
  }
}
```
The following parameters define a local connection profile:
* TargetAgent - The Control-M/Agent to which to deploy the connection profile.
* TargetCTM - 	The Control-M/Server to which to deploy the connection profile. If there is only one Control-M/Server, that is the default.

### Centralized connection profile definition
Centralized connection profiles are handled in one central location, and they are available to all agents.

To convert a local connection profile to a centralized connection profile, we must modify the connection profile definitions.
```
{
  "CONNECTION_STRING_NAME": {
    "Type": "ConnectionProfile:Database:Oracle:ConnectionString",
    "ConnectionString": "CONNECTION:1521:ORCL",
    "User": "USER",
    "Password": { "Secret": "SECRET_NAME" }
    "Centralized": true,
  }
}
```
As you can see:
* "TargetAgent" and "TargetCTM" are not relevant and are not specified.
* The "Centralized" parameter is added with a value of "true". 

### Prerequisites
* Control-M Automation API 9.0.20.000 or higher
* Python 3.6 or higher (lower versions may work but have not been tested)

### Script
A Python script was developed to facilitate the conversion of local connection profiles to centralized connection profiles. The script uses Control-M Automation API requests to achieve the following:
1. Gets a list of local connection profiles **by type** from Control-M. 
2. Converts local connection profiles to centralized connection profiles. 
Note: When getting connection profiles from Control-M, all password definitions are hidden. You MUST replace all hidden passwords with real passwords or secrets. In the script, all passwords are specified as secrets.
3. Writes the converted list of centralized connection profiles in a temporary json file. 
4. Builds (that is, validates) the converted list of centralized connection profiles.
5. Deploys validated centralized connection profiles to Control-M. Optional.

The complete [script](./scripts/).

### Deleting a local connection 
After the deployment step, you'll have local connection profiles and centralized connection profiles with the same names.
If you have a local connection profile and a centralized connection profile with the same name, the local connection profile takes precedence. Therefore, you must to delete your old local connection profiles.

**BEFORE DELETION** It is recommended to review and validate your new centralized connection profiles. If everything is ok, you can go ahead and delete your old local connection profiles. Use the following API command:
```
ctm deploy connectionprofile:local::delete "SERVER" "AGENT" "LOCAL_CONNECTION_TYPE" "LOCAL_CONNECTION_NAME"
``` 
	
### References
See the [Automation API - Code Reference - Connection Profiles](https://docs.bmc.com/docs/display/workloadautomation/API+Code+Reference+-+Connection+Profiles) documentation.

For more information about the deletion of local connection profiles, see the description of **deploy connectionprofile:local::delete** in  [Automation API - Code Reference - Deploy Service](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Deploy+service)

For more information about the use of secrets for passwords, see [Secrets in Code](https://docs.bmc.com/docs/display/workloadautomation/API+Code+Reference+-+Secrets+in+Code).