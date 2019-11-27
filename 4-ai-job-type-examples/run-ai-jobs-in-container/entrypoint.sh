#! /bin/bash

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
    exit 0
}

function sigtermHandler() {
    echo '========================================================================'
    echo 'Received signal SIGTERM'
    echo '========================================================================'
    removeAgentFromServer
    exit 0
}

function sigintHandler() {
    echo '========================================================================'
    echo 'Received signal SIGINT'
    echo '========================================================================'
    removeAgentFromServer
    exit 0
}

function getControlmPassword() {

    if [ ! -z "$CTM_PASSWORD" ]; then
        echo "CTM_PASSWORD env var was provided, so skip keymaker lookup"
        return 0
    elif [ ! -z "$PASS_FILE" ]; then
        if [ -f "$PASS_FILE" ]; then
        CTM_PASSWORD=$(cat $PASS_FILE)
        return 0
        else
        echo "Can't find auth file: $PASS_FILE"
        return 1
        fi
    else
        echo "Must specify either -pw password or -pf ./passfile"
        exit 2
    fi

}

function deployAppPack() {
    if [ ! -z "$AP_VER" ]; then
        echo "AppPack version was provided, not checking latest AppPack version avaliable."
    else
        AP_VER=$(ctm provision upgrades:versions::get | jq '[.[] | select(.[] | contains("AppPack"))] | max_by(.version | [splits("[.]")] | map(tonumber)) | .version' | sed 's/"//g')
    fi

    echo "Deploying Application Pack version $AP_VER to Agent [$ALIAS] in Control-M/Server [$CTM_SERVER]"
    upgradeId=$(ctm provision upgrade::install $CTM_SERVER $ALIAS AppPack $AP_VER | jq '.upgradeId' | sed 's/"//g')
    RC=$?

    if [[ ! -z "$DEPLOY_RETRIES" && "$upgradeId" == "" ]]; then
        tries=1
        while [[ "$tries -lt $DEPLOY_RETRIES" && $upgradeId == "" ]]; do
            echo "Pausing before retring AppPack deploy"
            sleep 10
            echo "Retrying AppPack deploy [Try number $tries]"
            upgradeId=$(ctm provision upgrade::install $CTM_SERVER $ALIAS AppPack $AP_VER | jq '.upgradeId' | sed 's/"//g')
            tries=$((tries+1))
        done
    fi

    if [[ "$RC" != "0" || "$upgradeId" == "" ]]; then
        echo "Problem running: \"ctm provision upgrade::install $CTM_SERVER $ALIAS AppPack $AP_VER\""
        return 110
    fi
    while [[ "$status" != "Completed" || "$status" != "Canceled" || "$status" != "Failed" || "$status" != "Unavailable" ]]; do
        sleep 30
        status=$(ctm provision upgrade::get $upgradeId | jq '.status')
        echo "Status of deployment [$upgradeId] is $status"
    done
    if [ "$status" != "Completed" ]; then
        echo "Deployment of AppPack failed with status $status"
        return 109
    else
        echo "Deployment of AppPack ended successfully"
    fi
}

function runCtmAgGetCm() {
    ag_ping 2>1 1>/dev/null
    # RC=$?
    # if [ "$RC" != "0" ]; then
    #     echo "Failed running ag_ping"
    # fi
    ctmaggetcm 2>1 1>/dev/null
    RC=$?
    # if [ "$RC" != "0" ]; then
    #     echo "Failed running ctmaggetcm"
    # fi
    return $RC
}

function deployAIJobTypes() {
    # echo "Pinging Control-M/Agent to ensure it is visiable before deploying AI Job Types"
    ctm config server:agent::ping $CTM_SERVER $ALIAS 2>1 1>/dev/null
    IFS=','
    read -ra JobTypeArray <<< "$AIJobTypes"
    for i in "${JobTypeArray[@]}"; do
        status=$(ctm deploy ai:jobtypes::get -s "jobTypeId=$i" | jq '.jobtypes[0].status' | sed 's/"//g')
        if [[ "$status" != "ready to deploy" ]]; then
            echo "AI Job Type with ID $i is not ready to deploy"
            fail="true"
        fi
    done
    if [[ ! -z "$fail" ]]; then
        echo "One or more AI Job Types are not ready to deploy"
        return 111
    fi
    for i in "${JobTypeArray[@]}"; do
        ctm deploy ai:jobtype $CTM_SERVER $ALIAS $i 2>1 1>/dev/null
        RC=$?
        if [ "$RC" != "0" ]; then
            # echo "Failed to deploy AI Job type with ID $i"
            return 112
        fi
    done


}

function deployConnProfile() {
    # echo "Pinging Control-M/Agent to ensure it is visiable before deploying AI Job Types"
    ctm config server:agent::ping $CTM_SERVER $ALIAS 2>1 1>/dev/null
    if [ ! -z "$DEPLOY_DESCRIPTOR" ]; then
        if [ ! -f "/tmp/dd_$$.json" ]; then
            envsubst < $DEPLOY_DESCRIPTOR > /tmp/dd_$$.json
            echo "Deploy Descriptor after envsubst:"
            cat /tmp/dd_$$.json
        fi
        res=$(ctm deploy $CONN_PROFILE /tmp/dd_$$.json)
        RC=$?
    else
        # echo "Deploying Connection Profile without Deploy Descriptor"
        res=$(ctm deploy $CONN_PROFILE)
        RC=$?
    fi

    if [ "$RC" != "0" ]; then
        # echo "Failed to deploy connection profile"
        return 115
    else
        echo $res
        return $RC
    fi
}

function usage() {
    # echo "usage: entrypoint.sh -s ctmserver -e https://controlm-host:8443/automation-api [-p 7006] -u controlmusername [-pw controlmpassword | -pf ./passwordfile] -i Agent_18.Linux -a agent-alias [-t AIID1[,TYPE2[,...]]] [-cp connection-profile.json [-dd deploydescriptor.json]] [-ai [--ap-ver 9.0.19.100]] [-r ]"
    echo -n "Usage: entrypoint.sh -s ctmserver -e endpointurl -u username [-pw password | -pf FILE] -i image.os -a alias [-t ID[,ID2[,IDn]]] [-cp FILE [-dd FILE]] [-r INT]
    Options:
        -s,     --server                Control-M/Server (Datacenter) name
        -e,     --endpoint              Automation API Endpoint URI. (Ex: https://controlmhost:8443/automation-api)
        -p,     --port                  Control-M/Agent listening port (Server-to-Agent)
        -u,     --user                  Control-M Username
        -pw,    --password              Control-M Password
        -pf,    --passfile              Path to file containing Control-M Password
        -i,     --image                 Automation API provisioning image informat name.os
        -a,     --alias                 Name to add new Control-M/Agent as on the Control-M/Server
        -t,     --types                 Comma seperated list of Control-M Application Integrator job types to deploy (requires -i set to an image that includes Application Pack)
        -cp,    --connection-profile    Path to json file containing connection profile(s) to be deployed to new Control-M/Agent
        -dd,    --deploy-descriptor     Path to deploy descriptor file to perform transform on connection profile json. \$ALIAS and \$CTM_SERVER will be replaced in the deploy descriptor 
                                        file with the values provided to -a and -s respectively"
    echo ""
}


while [ "$1" != "" ]; do
    case $1 in
        -t | --types  )     shift
                            AIJobTypes=$1
                            ;;
        -s | --server )     shift
                            export CTM_SERVER=$1
                            ;;
        -e | --endpoint )   shift
                            CTM_ENDPOINT=$1
                            ;;
        -p | --port )       shift
                            CTM_AGENT_PORT=$1
                            ;;
        -u | --user )       shift
                            CTM_USER=$1
                            ;;
        -pw | --password )  shift
                            CTM_PASSWORD=$1
                            ;;
        -pf | --passfile )  shift
                            PASS_FILE=$1
                            ;;
        -i | --image )      shift
                            IMAGE=$1
                            ;;
        -a | --alias )      shift
                            export ALIAS=$1
                            ;;
        -ai | --enable-ai ) DEPLOY_AP=1
                            ;;
        -r | --max-retries ) shift
                            DEPLOY_RETRIES=$1
                            ;;
        --ap-ver )          shift
                            AP_VER=$1
                            ;;
        -cp | --connection-profile ) shift
                            CONN_PROFILE=$1
                            ;;
        -dd | --deploy-descriptor ) shift
                            DEPLOY_DESCRIPTOR=$1
                            ;;
        -h | --help )       usage
                            exit
                            ;;
        * )                 usage
                            exit 1
    esac
    shift
done
        

# Script starts from here

echo
echo '========================================================================'
echo 'Start entrypoint.sh'
echo '========================================================================'
echo

getControlmPassword
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Failed to determine control-m password ($RC)"
    exit 101
else
    echo "Successfully determined control-m password"
fi

if [ -z "$CTM_AGENT_PORT" ]; then
    echo "No port specificed, defaulting to port 7006 for server-to-agent communication"
    CTM_AGENT_PORT=7006
fi
if [ -z "$ALIAS" ]; then
    echo "No alias specified, defaulting to host IP Address"
    ALIAS=$(hostname -i)
fi

if [ ! -z "$DEPLOY_DESCRIPTOR" ] && [ -z "$CONN_PROFILE" ]; then
    echo "Cannot use a deploy descriptor without a connection profile"
    exit 114
fi

if [ -z "$DEPLOY_RETRIES" ]; then
    DEPLOY_RETRIES=-1
fi

echo
echo ========================
echo
echo Creating agent named $ALIAS in data center $DATA_CENTER
echo
echo ========================
echo
# Setup to unregister agent before docker stop
trap 'sigusr1Handler' SIGUSR1
trap 'sigtermHandler' SIGTERM
trap 'sigintHandler' SIGINT

CTM_ENV=env
echo
echo '========================================================================'
echo Set controlm environment \"$CTM_ENV\"
echo '========================================================================'
echo


cd /home/controlm
ctm env add $CTM_ENV $CTM_ENDPOINT $CTM_USER $CTM_PASSWORD
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
echo 'Provision and register control-m agent image'
echo '========================================================================'
echo

cat << EOF > /tmp/provision_config.json
{
    "connectionInitiator": "AgentToServer"
}
EOF

ctm provision agent::install $IMAGE $CTM_SERVER $ALIAS $CTM_AGENT_PORT -f /tmp/provision_config.json
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Failed to connect & register image with control-m environment ($RC)"
    removeAgentFromServer
    exit 5
else
    echo "Successfully connected & registered image with control-m environment"
    . ~/.bash_profile
fi

if [ ! -z "$HOST_GROUP" ]; then
    ctm config server:hostgroup:agent::add $CTM_SERVER $HOST_GROUP $ALIAS
fi

if [ ! -z "$DEPLOY_AP" ]; then
    runCtmAgGetCm
    deployAppPack
    RC=$?
    if [[ $RC -ne 0 ]]; then
        echo "Failed to deploy Application Pack ($RC)"
        removeAgentFromServer
        exit 5
    else
        echo "Successfully deployed Application Pack"
    fi
fi

if [ ! -z "$AIJobTypes" ]; then
    echo -n "Trying to deploy AI Job Type(s).."
    n=0
    while true; do
        if [[ $n -eq $DEPLOY_RETRIES ]]; then
            removeAgentFromServer
            exit 5
        fi
        runCtmAgGetCm
        RC=$?
        if [ "$RC" == "0" ]; then
            break
        fi
        sleep 10
        n=$((n+1))
    done

    i=0
    while true; do
        echo -n '.'
        if [[ $i -eq $DEPLOY_RETRIES ]]; then
            echo "Failed to deploy AI Job Type(s) ($RC)"
            removeAgentFromServer
            exit 5
        fi
        deployAIJobTypes
        RC=$?
        if [ "$RC" == "0" ]; then
            break
        fi
        sleep 10
        i=$((i+1))
    done

    echo "Successfully deployed AI Job Type(s)"
fi


if [ ! -z "$CONN_PROFILE" ]; then
    echo -n "Trying to deploy Connection Profile(s).."
    n=0
    while true; do
        if [[ $n -eq $DEPLOY_RETRIES ]]; then
            removeAgentFromServer
            exit 5
        fi
        runCtmAgGetCm
        RC=$?
        if [ "$RC" == "0" ]; then
            break
        fi
        sleep 10
        n=$((n+1))
    done

    i=0
    while true; do
        echo -n '.'
        if [[ $i -eq $DEPLOY_RETRIES ]]; then
            echo "Failed to deploy Connection Profile(s) ($RC)"
            removeAgentFromServer
            exit 5
        fi
        deployConnProfile
        RC=$?
        if [ "$RC" == "0" ]; then
            break
        fi
        # echo "Waiting for deployed AI jobtype(s) to become visiable for Connection Profile deployment"
        sleep 10
        i=$((i+1))
    done

    echo "Successfully deployed Connection Profile(s)"
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
