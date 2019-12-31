#!/bin/bash

set +x

Env=""

if [ $# -gt 0 ] ; then
        Env="-e "$1
fi
#
#       Calculate 24 hours ago
#
DELTA=1
dataset_date=`date`
TIMENOW=`date +%T`
PREVDAY=`date -d "$dataset_date - $DELTA days" +%Y-%m-%d`T$TIMENOW

#
#	Retrieve all instance termination events from AWS Cloudtrail for last 24 Hours
#
TID=`aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=TerminateInstances --start-time $PREVDAY --query 'Events[*].Resources[*].ResourceName' | grep i- | sed s/[^a-zA-Z0-9_-]//g`

#
#	Get all Control-M Servers in this environment
#
CLIST=`ctm config servers::get $Env | grep name | cut -d ':' -f 2 | sed 's/[ ",]//g'`



for c in $CLIST; do
	echo Control-M Server: $c
	#
	#	Get all agents connected to this Control-M Server
	#
	ALIST=`ctm config server:agents::get $c $Env | grep nodeid | cut -d ':' -f 2,3 | sed 's/[ ",]//g'`
	
	#
	#	Get all hostgroups for this Control-M Server
	#
	HLIST=`ctm config server:hostgroups::get $c $Env | grep  [0-9A-Za-z:.-] | sed 's/[ ",]//g'`

	#
	#	For each termination event, check:
	#	1) 	Is there an agent with the name <any string>:<Instance-Id> matching this Terminatedinstances Event>
	#	2)	If such an agent exists, remove it from all hostgroups in the current Control-M Server
	#	3)	Delete the agent
	#
	for i in $TID; do 
		echo \>\> Instance from CloudTrail: $i
		
		#
		#	1) 	Is there an agent with the name <any string>:<Instance-Id> matching this Terminatedinstances Event>
		#
		for a in $ALIST; do
			echo \>\>\>\> Agent: $a
			aid=`echo $a | cut -f 2 -d ':'`
			if [ $aid == $i ] ; then 
				echo \>\>\>\>\>\> Agent to delete is $a
				
				#
				#	2)	If such an agent exists, remove it from all hostgroups in the current Control-M Server 
				#
				for h in $HLIST; do
					echo \>\>\>\>\>\>\>\> Hostgroup: $h
					ctm config server:hostgroup:agent::delete $c $h $a $Env
				done
				
				#
				#	3)	Delete the agent
				#
				ctm config server:agent::delete $c $a $Env
			fi
		done	
	done
done

