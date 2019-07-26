#!/bin/bash
#------------------------------------
# This script will update the Authorized Servers at all the agents in array of AGENTS_ARRAY. 
#------------------------------------

#Please update below variables accordingly
#CTM_ENV: the alias name of Control-M Automation API Server
#AAPI_HOST: the hostname of Control-M Automation API Server
#AAPI_PORT: the port of Control-M Automation API Server
#AAPI_USER: the user to login Control-M Automation API Server
#AAPI_PASSWORD: the password to AAPI_USER
CTM_ENV=xxxx
AAPI_HOST=xxxx
AAPI_PORT=xxxx
AAPI_USER=xxxx
AAPI_PASSWORD=xxxx

#CURRENT_AUTHORIZED_CTM_SERVER: the current authorized Control-M Server at Control-M/Agent
#NEW_ADDED_AUTHORIZED_CTM_SERVER: the desired authorized Control-M Server at Control-M/Agent
#CTM_SERVER: the Control-M server which Control-M/Agent is connecting to now
CURRENT_AUTHORIZED_CTM_SERVER=xxxx
NEW_ADDED_AUTHORIZED_CTM_SERVER=xxxx
CTM_SERVER=xxxx

#Please add Control-M/Agents into the () here to build an array, please leave a space between the Control-M/Agents
#For example AGENTS_ARRAY=(testagent1 testagent2)
AGENTS_ARRAY=(xxxx yyyy)

# add EM Automation API server endpoint
ctm env add endpoint https://$AAPI_HOST:$AAPI_PORT/automation-api $AAPI_USER $AAPI_PASSWORD && ctm env set endpoint


CONNECTOR="|"
DESIRED_CTM_SERVER="$CURRENT_AUTHORIZED_CTM_SERVER$CONNECTOR$NEW_ADDED_AUTHORIZED_CTM_SERVER"
#echo $DESIRED_CTM_SERVER

for AGENT in "${AGENTS_ARRAY[@]}"  
do  
    ctm config server:agent:param::set $CTM_SERVER $AGENT "CTMPERMHOSTS" "$DESIRED_CTM_SERVER"
	if [ $? -eq 0 ]; then
		echo "Control-M/Agent $AGENT Authorized Servers have been change to $DESIRED_CTM_SERVER"
		echo ""
	else
		echo "Failed to update Control-M/Agent $AGENT Authorized Servers!"
		echo ""
		exit 1
	fi
done  


exit 0
