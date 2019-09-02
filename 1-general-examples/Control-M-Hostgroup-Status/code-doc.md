This document explains the functionality of individual sections of the [hostgroup_list.py](./hostgroup_list.py) script.

It is broken down into two main sections:
* Automation API calls
    * Explains how the call to Automation API is performed, what data is returned, and how that data is used.
* Generic Python
    * Provides a high level over view of sections of sections of the code that don't directly interact with Automation API. This is provided ti give general functionality information for context.

### Table of Contents:
##### Automation API calls
1. [Login](./code-doc.md#login)
2. [Get Hostgroups](./code-doc.md#get-hostgroups)
3. [Get Hostgroup Agents](./code-doc.md#get-hostgroup-agents)
4. [Agent Ping](./code-doc.md#agent-ping)
##### Generic Python
1. [Argparse](./code-doc.md#argparse)
2. [Urllib3](./code-doc.md#urllib3)
3. [AESCipher class](./code-doc.md#aescipher-class)
4. [Threading](./code-doc.md#threading)
5. [Tabulate](./code-doc.md#tabulate)

### Automation API calls:
All Automation API calls are performed by functions of the lst class. All REST requests in this script make use of the python module `requests`, for more information on using this module see the documentation here: [https://2.python-requests.org/en/stable/](https://2.python-requests.org/en/stable/)

##### Login
The login is performed in the `update_token` function and uses the [session login](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Session+service#Sessionservice-sessionlogin) service of Automation API.

The login request in this function done on [line 390-392](./hostgroup_list.py#L390-392), stripping out the extra functionality (try except block, decrypting the encrypted password, etc), the login request in it's simplest form can look like:
```python
import requests
r = requests.post('https://myhost:8443/automation-api/session/login', json={"password": 'myB@dPa$$w0rd', "username": 'MyUser'})
print(r.text)
```

If the SSL Certificate on the endPoint is not trusted, this will result in execption, so the ```verify``` argument is passed with a value of ```False```:

```python
import requests
r = requests.post('https://myhost:8443/automation-api/session/login', json={"password": 'myB@dPa$$w0rd', "username": 'MyUser'}, verify=False)
print(r.text)
```
In the example script, value passed to the verify argument is pulled from the configuration file instead of being hard coded.

Lastly each request is wrapped in a try except block so that if any connection errors occur, reasonable errors can be generated. However, this is out of the scope of this section.

This function is used to authenticate to Automation API and retrieve a token, which is needed to authenticate later requests.

##### Get Hostgroups
The function ```gethostgroups``` uses the [config server:hostgroups::get](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-configserver:hostgroups::get) service of Automation API to retrieve a list of the hostgroups that exist on the specified Control-M/Server.

This request requires the authentication token to be passed in the header, and the name of the Control-M/Server to be passed in the URL.

The most simplified form of the request on [line 277-279](./hostgroup_list.py#L277-279) would look like:
```python
import requests

ctm='my-ctm-server'
token='fake-token'
r = requests.get('https://myhost:8443/automation-api/config/server/' + ctm + '/hostgroups', headers={"Authorization": "Bearer " + token},)
print(r.text)
```

In this simplified example, the ctm variable is the name of the Control-M/Server, that has the hostgroups we are interested in, and token is the authentication token retrieved from the login request.

When the request is successful, the result is a list(array) of hostgroups defined on the Control-M/Server.

Example response:
```
[
  "hostgroup1",
  "otherhostgrp",
  "last-host-grp"
]
```

##### Get Hostgroup Agents
The function ```getagents``` uses the [config server:hostgroup:agents::get](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-configserver:hostgroup:agents::get) Automation API service to get the list of all of the in a particular hostgroup. The request requires:
* authentication token in the header
* Control-M/Server name as a URL parameter
* Hostgroup name as a URL parameter

A simplified example of making this request in python would look like:
```python
import requests

ctm='my-ctm-server'
token='fake-token'
hstgrp='my-host-group'

r = requests.get('https://myhost:8443/automation-api/config/server/' + ctm + '/hostgroup/' + hstgrp + '/agents', headers={"Authorization": "Bearer " + token},)
print(r.text)
```

Example response:
```
[
  {
    "host": "db-node-01"
  },
  {
    "host": "db-node-02"
  },
  {
    "host": "db-node-03"
  }
]
```

##### Agent Ping
The `worker_thread` function uses the [config server:agent::ping](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-configserver:agent::ping) Automation API service to get up to date status information for the Control-M/Agents that are members of hostgroups.

This request requires the following inputs:
* authentication token in the header
* Control-M/Server name as a URL parameter
* Control-M/Agent name as a URL parameter    

Note: The below parameters are optional in the official Automation API ctm cli, but when making the rest call directly (ie. Using curl, python, etc) a JSON formate requst body is required.
* discover (Boolean) as part of the post body
    * Specifies if the Control-M/Agent should be added to the Control-M/Server if it does not already exist
    * In this example it is hard coded to `False`
* timeout (Integer) as part of the post body
    * Maximum time (in seconds) to wait for the Control-M/Agent to respond to the ping request
    * In this example it is hard coded to `30` to limit maximum execution time. The example could be updated to pull the value from the config file.

A simplified example of using python to make this call would look like:
```python
import requests

ctm='my-ctm-server'
token='fake-token'
agt='my-agt-01'

r = requests.post('https://myhost:8443/automation-api/config/server/'+ ctm + '/agent/' + agt + '/ping', headers={"Authorization": "Bearer " + token}, json={"discover": False, "timeout": 30})

print(r.text)
```

Example Response:
```
{
  "message": "Agent my-healthy-host is available"
}
```
or...
```
{
  "message": "Agent my-sick-host is unavailable"
}
```



Note: The [config server:agents::get](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-config_server_agents_getconfigserver:agents::get) service could have been used instead, but this shows the status information for the last time the Control-M/Server performed a life check to these specific Control-M/Agents. While this process is reliable and great for most use cases, in this example we opt'ed to use the ping service for each agent to force a status update to ensure the information is update to date.

### Generic Python:
This section will provide an overview some of the non-Automation API specific sections of code in the example script to provide context.

The information is broken down into sub-sections based on the type of action or function the code provides.

For more information on any of these specific components, please reference the documentation referenced below.

##### Argparse
This example makes use of the [argparse](https://docs.python.org/3/library/argparse.html) module to do more advanced argument parsing, including sub-commands, than is easily accomplished with only the `sys.argv` module.

The documentation for argparse is extreamly exhostive, and if you want to make use of it in your own projects they provide a very good [tutorial](https://docs.python.org/3/howto/argparse.html#id1) as an introduction.

##### Urllib3
The following quoted line from [hostgroup_list.py](./hostgroup_list.py#L17) uses the [urllib3](https://urllib3.readthedocs.io/en/latest/) module to disable the warning message that would be otherwise printed to standard error each and every time a request is made (using the `requests` module in this case) to an https endpoint with out a trusted certificate.  

>urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

As this scenario is quite common (in test/dev environments, or when using the Automation API workbench appliance), and in some cases the number of requests performed by this script, hence the number of times the warning would be printed, we chose to disable the warning.

##### AESCipher class

The `AESCipher` class seen in this example leverages the `Crypto.Cipher.AES` class provided by [pycryptodome](https://pycryptodome.readthedocs.io/en/latest/) to:
* Generate a random key (if the `$HOME/.ctm_hostgroup_list/env.key` does not already exist)
* Encrypt the password provided when running `python hostgroup_list.py env add ...` and store the encrypted form in `$HOME/.ctm_hostgroup_list/env.json`
* Decrypt the encrypted password, using the key, only when a [login](./code-doc.md#login) is run

##### Threading

This example makes use of the python built in [threading](https://docs.python.org/3/library/threading.html) module, and the python built in [queue](https://docs.python.org/3/library/queue.html) module.

Multithreading was used in this case as a result of the design choice to perform a ping request for each agent that is a part of a hostgroup. As this could result in a large number of request needing to be performed, and if many of the agents being checked are off line the 30 second timeout would begin to add up quickly in a single threaded implementation.

An in depth example on how to implement threading and queue in python is beyond the scope of this document, however the documentation linked above provide such in depth information.  

##### Tabulate
The `print_res` function of the `lst` class uses the [tabulate](https://pyhdust.readthedocs.io/en/latest/tabulate.html) module to format the results to be more visually appealing. As the raw results are stored in a nested [dict](https://docs.python.org/3/c-api/dict.html).  

Example:  
```
{
  "hostgroups": {
    "hostgroup01": {
      "agent01-a": "Online",
      "agent01-b": "Online"
    },
    "hostgroup02": {
      "agent02-a": "Offline",
      "agent02-b": "Online"
    }
  }
}
```

The data needs to be transformed into the format that is required by tabulate. The below quote is from the top of the first page of the tabulate docs linked above:

>The first required argument (tabular_data) can be a list-of-lists (or another iterable of iterables), a list of named tuples, a dictionary of iterables, an iterable of dictionaries, a two-dimensional NumPy array, NumPy record array, or a Pandas’ dataframe.

To accomplish this, our example iterates through the `resmap` nested dict with the following logic:
* create empty list named `tmp`
* for each hostgroup
    * print the hostgroup name
    * for each agent in hostgroup
        * append to `tmp` a list of `[agentname, agentstatus]`
    * pass `tmp` to `tabulate` with the optional settings: `tablefmt="grid", headers={'host', 'status'}` (inside of a print statement)
