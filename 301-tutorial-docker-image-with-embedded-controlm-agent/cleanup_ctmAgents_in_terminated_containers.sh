#!/bin/bash

set +x

Env=""

if [ $# -gt 0 ] ; then
        Env="-e "$1
fi

DHOST=${HOSTNAME}
echo Running on Docker host=$DHOST

#
#	Get all Control-M Servers in this environment
#
SLIST=`ctm config servers::get $Env | grep name | cut -d ':' -f 2 | sed 's/[ ",]//g'`



for s in $SLIST; do
	echo Control-M Server: $s
	#
	#	Get all agents connected to this Control-M Server
	#
	ALIST=`ctm config server:agents::get $s $Env | grep nodeid | cut -d ':' -f 2,3 | sed 's/[ ",]//g'`
	
	#
	#	Get all hostgroups for this Control-M Server
	#
	HLIST=`ctm config server:hostgroups::get $s $Env | grep  [0-9A-Za-z:.-] | sed 's/[ ",]//g'`

	#
	#	For each agent, check:
	#	1) 	Is this an agent with the name <docker host>:<container-Id> not matching any running container>
	#	2)	If such an agent exists, remove it from all hostgroups in the current Control-M Server
	#	3)	Delete the agent from the Control-M Server
	#
	for a in $ALIST; do 
	#
	#	1) 	Is there an agent with the name <docker host>:<container-Id> not matching any running container>
	#
        DCHECK=`echo $a | grep "^[A-Za-z0-9.+_-]*:[a-f0-9]*$"`
        DCHECKRC=$?
    	CIDFound=0		# Initialize Found ContainerID indicator
        if [[ $DCHECKRC -eq 0  ]] ; then
			ahost=`echo $a | cut -f 1 -d ':'`
			aid=`echo $a | cut -f 2 -d ':'`
			echo \>\> Checking Docker agent: $a $ahost $aid
			#
			#	Retrieve all currently running container IDs on this host
			#
			CID=`sudo docker ps | grep -v "CONTAINER ID" | cut -d ' ' -f 1`
			for c in $CID; do
		
				if [[ $aid = $c ]] ; then
				#
				#	There's a running container with this ID
				#
					CIDFound=1
					continue
				fi 
			done
			if [[ $CIDFound -eq 0 ]] ; then
				echo \>\>\>\>\>\> Found agent without running container: $a	
				#
				#	2)	If such an agent exists, remove it from all hostgroups in the current Control-M Server 
				#
				for h in $HLIST; do
					echo \>\>\>\>\>\>\>\> Deleting agent from hostgroup: $a $h
					ctm config server:hostgroup:agent::delete $s $h $a $Env
				done
			
				#
				#	3)	Delete the agent
				#
				echo \>\>\>\>\>\>\>\> Deleting agent from server: $a $s
				ctm config server:agent::delete $s $a $Env
			fi
		fi
	done
done

