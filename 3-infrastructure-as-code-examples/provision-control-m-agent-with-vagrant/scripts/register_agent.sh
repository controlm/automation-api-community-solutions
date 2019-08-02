#!/bin/bash

if [ -f ~/.ctm_env ]; then
   . ~/.ctm_env
fi

CTM_ENV=endpoint
ALIAS=$CTM_AGENT_HOST:$CTM_AGENT_PORT

echo run and register controlm agent [$ALIAS] with controlm [$CTM_SERVER], environment [$CTM_ENV] 
ctm provision setup $CTM_HOST $ALIAS $CTM_AGENT_PORT -e $CTM_ENV

exit 0
