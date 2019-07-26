This document explains the functionality of individual sections of [DecommissionAgent.sh](./DecommissionAgent.sh) script and what Automation API CLIs are performed.


### Table of Contents:
##### Automation API CLI
1. [Remove Agent from HostGroup](./code-doc-DecommissionAgent.md#remove-agent-from-hostgroup)
2. [Unregister Agent](./code-doc-DecommissionAgent.md#unregister-agent)


### Automation API CLI:
As prerequisite, the Control-M Automation API CLI needs to be installed at the machine where this script will be executed. 


##### Remove Agent from HostGroup
This uses

  * [ctm config server:hostgroup:agent::add] to remove a Control-M/Agent from the hostgroup. If the group is empty after the deletion, it is also deleted.
		https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-configserver:hostgroup:agent::delete

```
ctm config server:hostgroup:agent::delete $CTM_SERVER $CTM_HOSTGROUP $AGENT_ALIAS -e $CTM_ENV
```

 In the example script, 
 
    # CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
	# AGENT_ALIAS: the logical name of Control-M/Agent, by default it is the local hostname
	# CTM_HOSTGROUP: the name of the HostGroup
	# CTM_ENV: the alias name of Control-M Automation API Server


##### Unregister Agent
This uses

  * [ctm config server:hostgroup:agent::add] to delete Control-M/Agent from the Control-M/Server database. 
		https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-configserver:agent::delete

```
ctm config server:agent::delete $CTM_SERVER $AGENT_ALIAS
```
In the example script, 

	# CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
	# AGENT_ALIAS: the logical name of Control-M/Agent, by default it is the local hostname
    
