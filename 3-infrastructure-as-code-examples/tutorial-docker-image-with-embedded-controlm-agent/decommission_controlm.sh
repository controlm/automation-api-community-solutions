#!/bin/bash

#CTM_ENV=endpoint
#CTM_SERVER=[CTM_HOST]
#CTM_HOSTGROUP=app1 
#ALIAS=$(hostname):$CTM_AGENT_PORT/
CID=$(cat /proc/1/cgroup | grep 'docker/' | tail -1 | sed 's/^.*\///' | cut -c 1-12)
AGHOST=$(hostname)
ALIAS=$AGHOST:$CID


#cd
#source .bash_profile

# If this container is relatively long-lived such that credentials for the endpoint may have changed, the following snippet updates the endpoint credentials
#
# Set up cli environment based on "docker run" CTMENV environment variable
# ctmDocker directory should be mounted by "-v" "docker run" argument. The following is a sample docker run:
# docker run --net host -v /home/username/ctmDocker:<user home directory from build>/ctmDocker -e CTM_ENV= ctmprod -e CTM_SERVER=controlm -e CTM_HOSTGROUP=appgroup01 -dt <image name>
ctm env del myctm
cp -f ctmDocker/$CTM_ENV/*.secret /home/ec2-user/
ctm env add myctm `cat endpoint.secret` `cat username.secret` `cat password.secret`
ctm env set myctm

echo delete or remove a controlm hostgroup [$CTM_HOSTGROUP] with controlm agent [$ALIAS]
ctm config server:hostgroup:agent::delete $CTM_SERVER $CTM_HOSTGROUP $ALIAS 

echo stop and unregister controlm agent [$ALIAS] with controlm [$CTM_SERVER] 
ctm config server:agent::delete $CTM_SERVER $ALIAS

exit 0
