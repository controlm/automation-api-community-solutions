#!/bin/bash

if [ -f ~/.ctm_env ]; then
   . ~/.ctm_env
fi

CTM_ENV=endpoint
ALIAS=$CTM_AGENT_HOST:$CTM_AGENT_PORT

echo stop and unregister controlm agent [$ALIAS] with controlm [$CTM_SERVER], environment [$CTM_ENV] 
ctm config server:agent::delete $CTM_SERVER $ALIAS

echo 
echo To uninstall Control-M/Agent execute the following:
echo ctm provision agent::uninstall

exit 0
