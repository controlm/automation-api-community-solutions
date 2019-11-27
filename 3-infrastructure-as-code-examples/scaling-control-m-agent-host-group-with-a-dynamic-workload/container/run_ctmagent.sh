#!/bin/bash

function installCtmCli() {
    pushd $HOME
    wget --no-check-certificate https://$CTM_HOST:8443/automation-api/ctm-cli.tgz
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "Failed to download the ctm-cli.tgz package from https://$CTM_HOST:8443/automation-api/ctm-cli.tgz ($RC)"
        exit 102
    fi
    sudo npm install -g ctm-cli.tgz
    RC=$?
    popd
    if [[ $RC -ne 0 ]]; then
        echo "Failed to install the ctm-cli.tgz package ($RC)"
        exit 103
    else
        echo "Successfully installed ctm-cli"
    fi

    return 0
}

function removeAgentFromHostGroup() {
	echo Remove agent [$ALIAS] on controlm [$CTM_SERVER] from host group [$HOST_GROUP]
	ctm config server:hostgroup:agent::delete $CTM_SERVER $HOST_GROUP $ALIAS
	# RC=$?
	# if [[ $RC -ne 0 ]]; then
  #       echo "Did not remove control-m agent hostgroup ($RC)"
  #   else
  #       echo "Successfully removed control-m agent from hostgroup"
  #   fi
  #
	# return $RC

}

function removeAgentFromServer() {

    # Remove agent from controlm server
    echo stop and unregister controlm agent [$ALIAS] with controlm [$CTM_SERVER], environment [$CTM_ENV]
    if [[ -n $HOST_GROUP ]]; then
        removeAgentFromHostGroup
    fi
    ctm config server:agent::delete $CTM_SERVER $ALIAS
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "Did not remove control-m agent from server ($RC)"
    else
        echo "Successfully removed control-m agent from server"
    fi

    return 0

}

function sigusr1Handler() {
    echo '========================================================================'
    echo 'Received signal SIGUSR1'
    echo '========================================================================'
    removeAgentFromServer
    return 0
}

function sigtermHandler() {
    echo '========================================================================'
    echo 'Received signal SIGTERM'
    echo '========================================================================'
    removeAgentFromServer
    return 0
}

function sigintHandler() {
    echo '========================================================================'
    echo 'Received signal SIGINT'
    echo '========================================================================'
    removeAgentFromServer
    return 0
}
function getControlmPassword() {

    if [ ! -z "$CTM_PASSWORD" ]; then
        echo "CTM_PASSWORD env var was provided, so skip keymaker lookup"
        return 0
    fi
	# TODO Add EnvVar that contains the secret name so that this can be cleaned up
	#files in /auth
	filecount=`ls -l /auth/* | wc -l`
	if [ "$filecount" -eq 1 ]; then
		CTM_PASSWORD=`cat /auth/*`
		return 0
	elif [ "$filecount" -eq 0 ]; then
		echo 'No file in /auth/, missing secret config'
                return 104
	else
		echo 'Too many files in /auth/, auth secret should have only 1 data element'
		return 105
	fi

}

# Script start from here

echo
echo '========================================================================'
echo 'Start run_ctmagent.sh'
echo '========================================================================'
echo
echo 'Received env vars'
echo
echo CTM_SERVER=$CTM_SERVER
echo CTM_AGENT_PORT=$CTM_AGENT_PORT
echo CTM_HOST=$CTM_HOST
echo CTM_USER=$CTM_USER
echo IMAGE=$IMAGE
echo
if [ -z "$CTM_SERVER" -o -z "$CTM_AGENT_PORT" -o -z "$CTM_HOST" -o -z "$CTM_USER" -o -z "$IMAGE" ]; then
    echo "Cannot start control-m agent unless all of the required env vars have been set"
    exit 1
fi
echo

HOST_IP=`hostname -i`
export HOST_IP

CTM_ENV="endpoint"
ALIAS=$HOST_IP


echo
echo ========================
echo
echo 'Install ctm-cli'
installCtmCli

echo
echo ========================
echo
echo 'Get control-m password'
echo

getControlmPassword
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Failed to determine control-m password ($RC)"
    exit 101
else
    echo "Successfully determined control-m password"
fi
echo
echo ========================
echo
echo Creating agent named $ALIAS in data center $DATA_CENTER
echo

# Setup to unregister agent before docker stop
trap 'sigusr1Handler' SIGUSR1
trap 'sigtermHandler' SIGTERM
trap 'sigintHandler' SIGINT

echo
echo '========================================================================'
echo Set controlm environment \"$CTM_ENV\"
echo '========================================================================'
echo


cd /home/controlm
ctm env add $CTM_ENV https://$CTM_HOST:8443/automation-api $CTM_USER $CTM_PASSWORD
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Failed adding control-m environment \"$CTM_ENV\" ($RC)"
    exit 2
else
    echo "Successfully added control-m environment \"$CTM_ENV\""
fi

unset CTM_PASSWORD

ctm env set $CTM_ENV
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Failed setting current control-m environment to \"$CTM_ENV\" ($RC)"
    exit 3
else
    echo "Successfully set current control-m environment to \"$CTM_ENV\""
fi

echo
echo '========================================================================'
echo 'Remove controlm agent from ctm/s in case it is already registered'
echo '========================================================================'
echo
removeAgentFromServer

echo
echo '========================================================================'
echo 'Provision controlm agent image'
echo '========================================================================'
echo

cd
ctm provision image $IMAGE
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Failed to provision control-m agent image ($RC)"
    exit 4
else
    echo "Successfully provisioned control-m agent image"
fi
echo
echo '========================================================================'
echo 'Register control-m agent image'
echo '========================================================================'
echo

if [[ $persistant == "true" ]]; then
cat << EOF > /tmp/prov_cfg.json
{
    "connectionInitiator": "AgentToServer"
}
EOF


ctm provision setup $CTM_SERVER $ALIAS $CTM_AGENT_PORT -f /tmp/prov_cfg.json
RC=$?
if [ -n $CTMSHOSTOVERRIDE ]; then
  old_ctmshost=$(grep CTMSHOST $HOME/ctm/data/CONFIG.dat | awk '{ print $2 }')
  sed -i "s/$old_ctmshost/$CTMSHOSTOVERRIDE/g" $HOME/ctm/data/CONFIG.dat
  bash -c "shut-ag -u controlm -p all && start-ag -u controlm -p all"
  ctm config server:agent::ping $CTM_SERVER $ALIAS
  RC=$?
  if [[ $RC -ne 0 ]]; then
      echo "Failed to connect & register image with control-m environment ($RC)"
      exit 5
  else
      echo "Successfully connected & registered image with control-m environment"
  fi
fi

if [[ $RC -ne 0 ]]; then
    echo "Failed to connect & register image with control-m environment ($RC)"
    exit 5
else
    echo "Successfully connected & registered image with control-m environment"
fi

else
  ctm provision setup $CTM_SERVER $ALIAS $CTM_AGENT_PORT
  RC=$?
  if [ -n $CTMSHOSTOVERRIDE ]; then
    old_ctmshost=$(grep CTMSHOST $HOME/ctm/data/CONFIG.dat | awk '{ print $2 }')
    sed -i "s/$old_ctmshost/$CTMSHOSTOVERRIDE/g" $HOME/ctm/data/CONFIG.dat
    bash -c "shut-ag -u contorlm -p all && start-ag -u controlm -p all"
    ctm config server:agent::ping $CTM_SERVER $ALIAS
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "Failed to connect & register image with control-m environment ($RC)"
        exit 5
    else
        echo "Successfully connected & registered image with control-m environment"
    fi
  fi
  if [[ $RC -ne 0 ]]; then
      echo "Failed to connect & register image with control-m environment ($RC)"
      exit 5
  else
      echo "Successfully connected & registered image with control-m environment"
  fi
fi


if [ -n $HOST_GROUP ]; then
    ctm config server:hostgroup:agent::add $CTM_SERVER $HOST_GROUP $ALIAS
fi

echo '========================================================================'
echo 'Sleep to keep docker container alive'
echo '========================================================================'
echo

while true; do sleep 60; done

echo
echo '========================================================================'
echo 'End run_ctmagent.sh'
echo '========================================================================'
echo

removeAgentFromServer

exit 0
