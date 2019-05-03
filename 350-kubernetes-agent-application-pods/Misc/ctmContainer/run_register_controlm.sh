#!/bin/bash

#CTM_ENV=[CTMENV]
#CTM_SERVER=[CTM_HOST]
#CTM_HOSTGROUP=[CTM_HOSTGROUP]
#CTM_AGPORT=[CTM_AGPORT]

# Get the container ID for informaiton
CID=$(cat /proc/1/cgroup | grep 'kubepods/' | tail -1 | sed 's/^.*\///' | cut -c 1-12)
# Combine Hostname and port number to get the Agent Alias
AGHOST=$(hostname)
ALIAS=$AGHOST:$CTM_AGPORT

echo Container ID is $CID, Hostname is $AGHOST and Alias is $ALIAS

#cd
#source .bash_profile

# Set up cli environment based on CTMENV environment variable from K8S Manifest
# ctmDocker directory should be mounted via VolumeMount in K8S manifest
cp -f ctmDocker/$CTM_ENV/*.secret /home/ec2-user/
ctm env del myctm
ctm env add myctm `cat endpoint.secret` `cat username.secret` `cat password.secret`
ctm env set myctm

# Cluster configuration for connecting to the API
mkdir /home/ec2-user/.kube/
cp $KUBE_CONFIG /home/ec2-user/.kube/config 

echo run and register controlm agent [$ALIAS] with controlm [$CTM_SERVER], environment [$CTM_ENV] 
ctm provision setup $CTM_SERVER $ALIAS $CTM_AGPORT

echo add or create a controlm hostgroup [$CTM_HOSTGROUP] with controlm agent [$ALIAS]
ctm config server:hostgroup:agent::add $CTM_SERVER $CTM_HOSTGROUP $ALIAS 

# loop forever
while true; do echo Running in K8S && sleep 120; done

exit 0
