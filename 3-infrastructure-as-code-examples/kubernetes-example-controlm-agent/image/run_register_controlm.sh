#!/bin/bash

CTM_ENV=endpoint
#CTM_SERVER=[CTM_HOST]
#CTM_HOSTGROUP=app0
#CTM_AGENT_PORT=$(shuf -i 7000-8000 -n 1)
ALIAS=$(hostname):$CTM_AGENT_PORT


function sigusr1Handler() {
    echo '========================================================================'
    echo 'Received signal SIGUSR1'
    echo '========================================================================'
    /home/controlm/decommission_controlm.sh
    return 0
}

function sigtermHandler() {
    echo '========================================================================'
    echo 'Received signal SIGTERM'
    echo '========================================================================'
    /home/controlm/decommission_controlm.sh
    return 0
}


#source .bash_profile

trap 'sigusr1Handler' SIGUSR1
trap 'sigtermHandler' SIGTERM

echo run and register controlm agent [$ALIAS] with controlm [$CTM_SERVER], environment [$CTM_ENV] 
ctm provision setup $CTM_SERVER $ALIAS $CTM_AGENT_PORT -f agent-parameters.json

echo add or create a controlm hostgroup [$CTM_HOSTGROUP] with controlm agent [$ALIAS]
ctm config server:hostgroup:agent::add $CTM_SERVER $CTM_HOSTGROUP $ALIAS -e $CTM_ENV

echo "Control-M Agent Available"
echo "Agent Name: $ALIAS"
echo "Agent Idle" 
# loop forever
while true
do 
  tail -f /dev/null & wait ${!} 
done

/home/controlm/decommission_controlm.sh
echo "Control-M last step"
 
exit 0
