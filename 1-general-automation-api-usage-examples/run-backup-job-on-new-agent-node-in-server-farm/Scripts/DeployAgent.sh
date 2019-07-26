#!/bin/bash
#------------------------------------
# Control-M Agent user needs to be created
# automation API prerequisite Node.js, JDK and CTM CLI must be embedded
#------------------------------------

#Please update below variables accordingly
#CTM_ENV: the alias name of Control-M Automation API Server
#CTM_AGENT: the logical name of Control-M/Agent
#AAPI_HOST: the hostname of Control-M Automation API Server
#AAPI_PORT: the port of Control-M Automation API Server
#AAPI_USER: the user to login Control-M Automation API Server
#AAPI_PASSWORD: the password to AAPI_USER
CTM_ENV=xxxx
CTM_AGENT=$(hostname)
AAPI_HOST=xxxx
AAPI_PORT=xxxx
AAPI_USER=xxxx
AAPI_PASSWORD=xxxx

#CTM_HOSTGROUP: the name of the HostGroup which Control-M/Agent will be added into
#CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
#CTM_AGENT_PORT: the port which Control-M/Agent will be listening on
#CTM_AGENT_USER: the Control-M/Agent user
CTM_HOSTGROUP=xxxx
CTM_SERVER=xxxx
CTM_AGENT_PORT=xxxx
CTM_AGENT_USER=xxxx

# add EM Automation API server endpoint
ctm env add endpoint https://$AAPI_HOST:$AAPI_PORT/automation-api $AAPI_USER $AAPI_PASSWORD && ctm env set endpoint

# provision controlm agent image
ctm provision image Agent.Linux

# register Control-M/Agent into Control-M/Server
echo run and register controlm agent [$CTM_AGENT] with controlm [$CTM_SERVER], environment [$CTM_ENV]
ctm provision setup $CTM_SERVER $CTM_AGENT $CTM_AGENT_PORT -e $CTM_ENV

# add Control-M/Agent into HostGroup
echo add or create a controlm hostgroup [$CTM_HOSTGROUP] with controlm agent [$CTM_AGENT]
ctm config server:hostgroup:agent::add $CTM_SERVER $CTM_HOSTGROUP $CTM_AGENT

exit 0
