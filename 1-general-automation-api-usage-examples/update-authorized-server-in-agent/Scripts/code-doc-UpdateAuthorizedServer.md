This document explains the functionality of individual sections of [UpdateAuthorizedServer.sh](./UpdateAuthorizedServer.sh) script.

The explanation for each script is broken down into two main sections:
* Automation API CLI
	* Explains which Automation API CLI is performed, what data is returned, and how that data is used.
* Generic Shell
	* Provides a high level over view of sections of sections of the code that don't directly interact with Automation API. This is provided to give general functionality information for context. 


### Table of Contents:
##### Automation API CLI
1. [Define Automation API endpoint](./code-doc-UpdateAuthorizedServer.md#define-automation-api-endpoint)
2. [Update Authorized Server List](./code-doc-UpdateAuthorizedServer.md#update-authorized-server-list)
##### Generic Shell
1. [Display Result](./code-doc-UpdateAuthorizedServer.md#display-result)

### Automation API CLI:
As prerequisite, the Control-M Automation API CLI needs to be installed at the machine where this script will be executed. 

##### Define Automation API endpoint
This uses

  * [ctm environment add] to add the Automation API endpoint
		https://docs.bmc.com/docs/automation-api/919110/environment-service-872868769.html#Environmentservice-environmentadd

  * [ctm environment set] to set it as the default Automation API endpoint
		https://docs.bmc.com/docs/automation-api/919110/environment-service-872868769.html#Environmentservice-environmentset

```
ctm env add endpoint https://$AAPI_HOST:$AAPI_PORT/automation-api $AAPI_USER $AAPI_PASSWORD && ctm env set endpoint
```
In the example script, 
   - AAPI_HOST: the hostname of Control-M Automation API Server
   - AAPI_PORT: the port of Control-M Automation API Server

##### Update Authorized Server List
This uses
  * [config server:agent:param::set] to udpate the Authorized Server List to desired value			https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-configserver:agent:param::set

```
ctm config server:agent:param::set $CTM_SERVER $AGENT "CTMPERMHOSTS" "$DESIRED_CTM_SERVER"
```
In the example script, 
   - DESIRED_CTM_SERVER: the desired authorized Control-M Server list at Control-M/Agent
   - AGENT: the name of Control-M/Agent
   - CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now


### Generic Shell:
This section will provide an overview some of the non-Automation API specific sections of code in the example script to provide context.

##### Display Result
The following quoted line from  [line 40-48](./UpdateAuthorizedServer.sh#L40-48) displays execution result.

* When CLI call has successfully updated the Authorized ServerList, it will display message 
	```
	"Control-M/Agent $AGENT Authorized Servers have been change to $DESIRED_CTM_SERVER"
	```
	- AGENT: the name of Control-M/Agent
	- DESIRED_CTM_SERVER: the desired authorized Control-M Server list at Control-M/Agent
	
* When CLI call has failed to update the Authorized ServerList, it will display message 
	```
	"Failed to update Control-M/Agent $AGENT Authorized Servers!"
	```



