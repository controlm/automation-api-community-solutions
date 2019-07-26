This document explains the functionality of individual sections of [DeployAgent.sh](./DeployAgent.sh) script and what Automation API CLIs are performed.


### Table of Contents:
##### Automation API CLI
1. [Define Automation API endpoint](./code-doc-DeployAgent.md#define-automation-api-endpoint)
2. [Provision Agent](./code-doc-DeployAgent.md#provision-agent)
3. [Register Agent](./code-doc-DeployAgent.md#setup-agent)
4. [Add Agent into HostGroup](./code-doc-DeployAgent.md#add-agent-into-hostgroup)


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
```
   #CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
   #AGENT_ALIAS: the logical name of Control-M/Agent, by default it is the local hostname
   #CTM_HOSTGROUP: the name of the HostGroup
   #CTM_ENV: the alias name of Control-M Automation API Server
```


##### Provision Agent
This uses

  * [ctm provision image "image" ] to downloads an image and prepares it for installation.
		https://docs.bmc.com/docs/automation-api/919110/provision-service-872868763.html#Provisionservice-provisionimage

```
ctm provision image Agent.Linux
```
In the example script, 
   -  "image" : is the Agent.Linux when deploying Control-M/Agent in Linux. To check the available images for the relavent OS, please use "ctm provision images <os>" CLI  https://docs.bmc.com/docs/automation-api/919110/provision-service-872868763.html#Provisionservice-provisionimages


##### Register Agent
This uses

  * [ctm provision agent::setup] to setup and register Control-M/Agent into Control-M/Server
		https://docs.bmc.com/docs/automation-api/919110/provision-service-872868763.html#Provisionservice-agent_setupprovisionagent::setup

```
ctm provision setup $CTM_SERVER $CTM_AGENT $CTM_AGENT_PORT -e $CTM_ENV
```

In the example script, 
```
   #CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
   #CTM_AGENT_PORT: the port which Control-M/Agent will be listening on
   #CTM_AGENT: the logical name of Control-M/Agent
   #CTM_ENV: the alias name of Control-M Automation API Server
```

##### Add Agent into HostGroup
This uses

  * [ctm config server:hostgroup:agent::add] to Adds a Control-M/Agent to the pre-defined HostGroup and creates the HostGroup if it does not exist.
		https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-configserver:hostgroup:agent::add

```
ctm config server:hostgroup:agent::add $CTM_SERVER $CTM_HOSTGROUP $CTM_AGENT
```

In the example script, 
```
   #CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
   #CTM_AGENT: the logical name of Control-M/Agent
   #CTM_HOSTGROUP: the name of the HostGroup which Control-M/Agent will be added into
```    

