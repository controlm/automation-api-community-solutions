#!/bin/tcsh

if (-f '.cshrc') then
         source .cshrc
endif

echo parameters: $argv
set AG_NODE_ID=`cat /etc/hostname`

set PERSISTENT_VOL=$1/$AG_NODE_ID
set CTM_SERVER_NAME=$2
set CTM_AGPORT=$3

if ("aa${CTM_AGPORT}aa" == "aaaa") then
  echo missing parameters during container startup, use: --evn PERSISTENT_VOL=predefine persistent volume --env CTM_SERVER_NAME=ctm_name --env CTM_AGPORT=7006
  exit 1;
else
  echo parameters validation passed
endif


# create if needed, and map agent persistent data folders
echo mapping persistent volume
cd /home/controlm
if (! -d $PERSISTENT_VOL/pid) then
		echo first time the agent is using the persistent volume, moving folders to persistent volume
		# no agent files exist in PV, copy the current agent files to PV
		mkdir $PERSISTENT_VOL
		mv $CONTROLM/backup $CONTROLM/capdef $CONTROLM/dailylog $CONTROLM/measure $CONTROLM/onstmt $CONTROLM/pid $CONTROLM/procid $CONTROLM/sysout $CONTROLM/status $CONTROLM/temp -t $PERSISTENT_VOL
else
		echo this is not the first time an agent is running using this persistent volume, mapping folder to existing persistent volume
		rm -Rf $CONTROLM/backup $CONTROLM/capdef $CONTROLM/dailylog $CONTROLM/measure $CONTROLM/onstmt $CONTROLM/pid $CONTROLM/procid $CONTROLM/sysout $CONTROLM/status $CONTROLM/temp
endif
# create link to persistent volume
ln -s $PERSISTENT_VOL/backup 	$CONTROLM/backup
ln -s $PERSISTENT_VOL/capdef 	$CONTROLM/capdef
ln -s $PERSISTENT_VOL/dailylog 	$CONTROLM/dailylog
ln -s $PERSISTENT_VOL/measure 	$CONTROLM/measure
ln -s $PERSISTENT_VOL/onstmt 	$CONTROLM/onstmt
ln -s $PERSISTENT_VOL/pid 		$CONTROLM/pid
ln -s $PERSISTENT_VOL/procid 	$CONTROLM/procid
ln -s $PERSISTENT_VOL/sysout 	$CONTROLM/sysout
ln -s $PERSISTENT_VOL/status 	$CONTROLM/status
ln -s $PERSISTENT_VOL/temp 	$CONTROLM/temp

# point CLI to request endpoint if one was requested
if ($?AAPI_END_POINT && $?AAPI_USER && $?AAPI_PASS) then
	echo using new AAPI configuration, not the default build time configuration
	ctm env add prod $AAPI_END_POINT $AAPI_USER $AAPI_PASS
	ctm env set prod
else
	echo using the default build time AAPI configuration
endif

# workaround to support a server located in a cloud environemnt 
echo applying workaround to hosts file
setenv SERVERIP `echo $AAPI_END_POINT | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'`
echo "$SERVERIP     $CTM_SERVER_NAME" | sudo tee -a /etc/hosts

echo configuring and registering the agent
# set JAVA_HOME to agent’s java 1.8 so provision can work
# provision the agent will also start it
if (-d /home/controlm/JRE) then
  setenv JAVA_HOME /home/controlm/JRE
  setenv PATH ${PATH}:/home/controlm/JRE/bin
else if (-d /home/controlm/bmcjava/bmcjava-V2) then
  setenv JAVA_HOME /home/controlm/bmcjava/bmcjava-V2
  setenv PATH ${PATH}:/home/controlm/bmcjava/bmcjava-V2/bin
else if (-d /home/controlm/ctm/JRE) then
  setenv JAVA_HOME /home/controlm/ctm/JRE
  setenv PATH ${PATH}:/home/controlm/ctm/JRE/bin
else if (! $?JAVA_HOME) then
  echo ERROR Unable to determine JAVA_HOME location
endif

echo using JAVA HOME: $JAVA_HOME
  #statements
ctm provision setup $CTM_SERVER_NAME $AG_NODE_ID $CTM_AGPORT -f agent_configuration.json


echo Running in agent container
sleep infinity
