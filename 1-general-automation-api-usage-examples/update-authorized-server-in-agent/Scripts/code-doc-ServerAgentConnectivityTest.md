This document explains the functionality of individual sections of [ServerAgentConnectivityTest.py](./ServerAgentConnectivityTest.py) script.

The explanation for each script is broken down into two main sections:
* Automation API calls
	* Explains how the call to Automation API is performed, what data is returned, and how that data is used.
* Generic Python
	* Provides a high level over view of sections of sections of the code that don't directly interact with Automation API. This is provided to give general functionality information for context. 


### Table of Contents:
##### Automation API calls
1. [Login](./code-doc-ServerAgentConnectivityTest.md#login)
2. [Track Agent Status](./code-doc-ServerAgentConnectivityTest.md#track-agent-status)
3. [Logout](./code-doc-ServerAgentConnectivityTest.md#logout)
##### Generic Python
1. [Urllib3](./code-doc-ServerAgentConnectivityTest.md#urllib3)
2. [Display Agent Status](./code-doc-ServerAgentConnectivityTest.md#display-agent-status)

### Automation API calls:
All Automation REST API requests in this script make use of the python module `requests`, for more information on using this module see the documentation here: [https://2.python-requests.org/en/stable/](https://2.python-requests.org/en/stable/)

##### Login
The login uses the [session login](https://docs.bmc.com/docs/automation-api/919110/session-service-872868771.html#Sessionservice-sessionlogin) service of Automation API. It is used to authenticate to Automation API and retrieve a token, which is needed to authenticate later requests.
The login request in this function done on [line 15-35](./ServerAgentConnectivityTest.py#L15-35), the login request in it's simplest form can look like:
```python
import requests
r_login = requests.post(endPoint + '/session/login', json=credentialAAPI)
```

If the SSL Certificate on the endPoint is not trusted, this will result in exception, so the ```verify``` argument is passed with a value of ```False```.

```python
import requests
r_login = requests.post(endPoint + '/session/login', json=credentialAAPI, verify=False)
```
In the example script, the username and password value are passed to the credentialAAPI argument in JSON format. 


##### Track Agent Status
This uses the [config server:agents::get](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-config_server_agents_getconfigserver:agents::get) Automation API service to get the list of all Agents Status. The request requires:
* authentication token in the header
* Control-M/Server name as a URL parameter
* Control-M/Agent name which will be searched, * can be used

A simplified example of making this request in python would look like:
```python
search_criteria = ctms + "/agents?agent=*"
urlAgentAvailabilityCheck = endPoint + '/config/server/' + search_criteria

r_responce = requests.get(urlAgentAvailabilityCheck,
						   headers={'Authorization': 'Bearer ' + token},
						   verify=False)
```
Note: the urlAgentAvailabilityCheck parameter determines which Control-M/Agents will be tracked

Example response:
```
{
  "agents": [
	{
	  "nodeid": "host1",
	  "status": "Available"
	},
	{
	  "nodeid": "host2",
	  "status": "Unavailable"
	}
  ]
}
```


##### Logout
The logout uses the [session logout](https://docs.bmc.com/docs/automation-api/919110/session-service-872868771.html#Sessionservice-sessionlogout) service of Automation API. It is used to logout from Automation API.
The logout request is done on [line 96-108](./ServerAgentConnectivityTest.py#L96-108), it can look like:
```python
r_logout = requests.post(endPoint + '/session/logout',
							 headers={'Authorization': 'Bearer ' + token},
							 verify=False)
```

If the SSL Certificate on the endPoint is not trusted, this will result in exception, so the ```verify``` argument is passed with a value of ```False```.



### Generic Python:
This section will provide an overview some of the non-Automation API specific sections of code in the example script to provide context.

The information is broken down into sub-sections based on the type of action or function the code provides.

For more information on any of these specific components, please reference the documentation referenced below.

##### Urllib3
The following quoted line from [ServerAgentConnectivityTest.py](./ServerAgentConnectivityTest.py#L2) uses the [urllib3](https://urllib3.readthedocs.io/en/latest/) module to disable the warning message that would be otherwise printed to standard error each and every time a request is made (using the `requests` module in this case) to an https endpoint with out a trusted certificate.  

>urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
  
As this scenario is quite common (in test/dev environments, or when using the Automation API workbench appliance), and in some cases the number of requests performed by this script, hence the number of times the warning would be printed, we chose to disable the warning.

##### Display Agent Status
The following quoted line from  [line 51-94](./ServerAgentConnectivityTest.py#L51-94) displays the Agent Status in below format
```
You have 2 Agents in Available status:
host1
host2

You have 3 Agents in Unavailable status:
host3
host4
host5
```
The Control-M/Agent status can be 

 . Available

 . Unavailable

 . Disable

 . Discovering

To accomplish this, our example will parse the response and transform the response into set format with the following logic:
* create 4 empty sets named agentAvailableSet, agentUnavailableSet, agentDisabledSet, agentDiscoveringSet
* transform the response into JSON format 
* iterate the JSON and parse the data
	* check each Agent status and put them into the respective set
