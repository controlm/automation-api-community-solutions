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


function removeServerFromEm() {

    # Remove agent from controlm server
    echo stop and unregister controlm server [$CTM_SERVER], environment [$CTM_ENV]

    ctm config server::delete $CTM_SERVER
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "Did not remove control-m server from Enterprise Manager ($RC)"
    else
        echo "Successfully removed control-m server from Enterprise Manager"
    fi

    return 0

}

function sigusr1Handler() {
    echo '========================================================================'
    echo 'Received signal SIGUSR1'
    echo '========================================================================'
    removeServerFromEm
    return 0
}

function sigtermHandler() {
    echo '========================================================================'
    echo 'Received signal SIGTERM'
    echo '========================================================================'
    removeServerFromEm
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
echo CTM_HOST=$CTM_HOST
echo CTM_USER=$CTM_USER
echo IMAGE=$IMAGE
echo
if [ -z "$CTM_SERVER" -o -z "$CTM_HOST" -o -z "$CTM_USER" -o -z "$IMAGE" ]; then
    echo "Cannot start control-m agent unless all of the required env vars have been set"
    exit 1
fi
echo


if [ -f '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt' ]; then
if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE=default
fi
# TODO determine service type and perform different action based on result
# TODO move this logic to it's own function
# SERVICE_NAME=`hostname | cut -d\- -f1,2,3`
# export SERVICE_NAME
# echo SERVICE_NAME=$SERVICE_NAME
echo ========================
# HOST_IP=`curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes/api/v1/namespaces/$NAMESPACE/services/ | python -c 'import sys, json, os; print json.dumps([item["status"]["loadBalancer"]["ingress"][0]["ip"] for item in json.load(sys.stdin)["items"] if item["metadata"]["name"] == sys.argv[1] ])[2:][:-2]' $INSTANCE`
HOST_IP=`curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/$NAMESPACE/services/$INSTANCE | python -c 'import sys, json; print json.dumps(json.load(sys.stdin)["status"]["loadBalancer"]["ingress"][0]["ip"])'`
echo $HOST_IP
HOST_IP=`echo $HOST_IP | cut -d\" -f2`
if [[ -z $HOST_IP ]]; then
  HOST_IP=$SERVICE_NAME
fi
echo HOST_IP=$HOST_IP
echo ========================
else
  HOST_IP=$(hostname)
  echo HOST_IP=$HOST_IP
fi
# SERVICE_NAME=`hostname`
# export SERVICE_NAME
# HOST_IP=$SERVICE_NAME
# export HOST_IP
# echo SERVICE_NAME=$SERVICE_NAME

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
echo Creating Control-M/Server data center name [$CTM_SERVER] in Control-M/Enterprise Manager
echo
echo ========================

# Setup to unregister agent before docker stop
trap 'sigusr1Handler' SIGUSR1
trap 'sigtermHandler' SIGTERM

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

# echo
# echo '========================================================================'
# echo 'Remove controlm agent from ctm/s in case it is already registered'
# echo '========================================================================'
# echo
# removeAgentFromServer

echo
echo '========================================================================'
echo 'Provision controlm server image'
echo '========================================================================'
echo

cd
# ctm provision image $IMAGE
# RC=$?
# if [[ $RC -ne 0 ]]; then
#     echo "Failed to provision control-m agent image ($RC)"
#     exit 4
# else
#     echo "Successfully provisioned control-m agent image"
# fi

sed "s/\"Hostname\": \"10.10.10.10\"/\"Hostname\": \"$HOST_IP\"/" /etc/ctms/ctms-configmap.json > ./ctms-configmap.json

ctm provision server::install $IMAGE -f ./ctms-configmap.json
RC=$?

if [[ $RC -ne 0 ]]; then
    sed -i "s/OS_PRM_HOSTNAME $HOST_IP/OS_PRM_HOSTNAME $(hostname)/" ~/ctm_server/data/local_config.dat
    sed -i "s/CTMSHOST   $HOST_IP/CTMSHOST   $(hostname)/;s/CTMPERMHOSTS   $HOST_IP/CTMPERMHOSTS   $(hostname)/" ~/ctm_agent/ctm/data/CONFIG.dat
    tcsh -c 'shut-ag -p all -u controlm && start_ctm && start_ca && start-ag -p all -u controlm'
    ctm config server::add $HOST_IP $INSTANCE $(echo $RANDOM | cut -c-3) $(grep ConfigurationAgentPort ctms-configmap.json | cut -d' ' -f10 | cut -d, -f1)
    RC=$?
    if [[ $RC -ne 0 ]]; then
    echo "Failed to connect & register image with control-m environment ($RC)"
    if [[ "$INSTALL_DEBUG" == "true" ]]; then
      echo "Skipping exit to allow debug"
    else
      exit 5
    fi
  else
      echo "Successfully modified params, connected & registered image with control-m environment"
  fi
else
    echo "Successfully connected & registered image with control-m environment"
fi

echo "Removing old default agent entry"
ctm config server:agent::delete $INSTANCE $HOST_IP
RC=$?
if [[ $RC -ne 0 ]]; then
  echo "Failed to remove old default agent. Please manually remove later."
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

removeServerFromEm

exit 0
