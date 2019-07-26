#!/bin/bash
#------------------------------------
# automation API prerequisite Node.js, JDK and CTM CLI must be embedded
#------------------------------------

#Please update below variables accordingly
#CTM_ENV: the alias name of Control-M Automation API Server
#AGENT_ALIAS: the logical name of Control-M/Agent, by default it is the local hostname
#CTM_HOSTGROUP: the name of the HostGroup which Control-M/Agent will be added into
#CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
CTM_ENV=xxxx
AGENT_ALIAS=$(hostname)
CTM_HOSTGROUP=xxxx
CTM_SERVER=xxxx

echo delete or remove a controlm hostgroup [$CTM_HOSTGROUP] with controlm agent [$AGENT_ALIAS]
ctm config server:hostgroup:agent::delete $CTM_SERVER $CTM_HOSTGROUP $AGENT_ALIAS -e $CTM_ENV

echo stop and unregister controlm agent [$AGENT_ALIAS] with controlm [$CTM_SERVER], environment [$CTM_ENV] 
ctm config server:agent::delete $CTM_SERVER $AGENT_ALIAS

exit 0