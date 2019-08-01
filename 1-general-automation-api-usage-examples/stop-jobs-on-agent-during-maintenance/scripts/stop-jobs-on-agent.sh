#!/bin/bash
#------------------------------------------------------------------------------------
#	Stop scheduling jobs to a host during maintenance 
#------------------------------------------------------------------------------------
endpoint=https://workbench:8446/automation-api
username=sysadmin
password=password
maxiterations=20    # number of iterations the script will check if jobs are still running
sleepinterval=15    # number of seconds between each interval

#logout function to be called before each exit when we're already logged in
ctmapi_logout () {
  curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"  > /dev/null
}


# Check script arguments
if [[ $# -ne 3 ]] ; then
    printf 'Usage: %s stop|start ctmserver agent\n' "$(basename "$0")"
    exit 1
fi

ctmserver=$2
agenthost=$3

# Login to Control-M API
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *token* ]] ; then
	token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)
else
	printf "Login failed!\n"
	exit 1
fi

case $1 in
   stop)
      # Check if Agent exists
      agents=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/config/server/$ctmserver/agents?agent=$agenthost")
      if [[ $agents == '{ }' ]] ; then
         printf "No Agent named \"%s\" found in Control-M/Server \"%s\"" "$agenthost" "$ctmserver"
         ctmapi_logout
         exit 1
      else
         # Disable the Agent
         result=$(curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/config/server/$ctmserver/agent/$agenthost/disable")
         echo ${result##*message\" : \"} | cut -d '"' -f 1
      fi

      # Check if jobs are still running on the Agent
      i=0
      result=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/run/jobs/status?host=$agenthost&status=Executing")
      returned=$(echo ${result##*returned\" : } | cut -d ',' -f 1)
      until [[ $returned == 0 || $i>=$maxiterations ]]; do
         printf "\r%s jobs still executing on agent %s..." "$returned" "$agenthost" 
         sleep $sleepinterval
         result=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/run/jobs/status?host=$agenthost&status=Executing")
         returned=$(echo ${result##*returned\" : } | cut -d ',' -f 1)
         i=$($i+1)
      done
      if [[ $returned > 0 ]]; then
         printf "\nContact Control-M administrator to check the jobs.\n"
         ctmapi_logout
         exit 1
      else 
         printf "\rNo jobs running on %s. OK to continue maintenance.\n" "$agenthost"
      fi
      ;;

   start)
      # Disable the Agent
      result=$(curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/config/server/$ctmserver/agent/$agenthost/disable")
      echo ${result##*message\" : \"} | cut -d '"' -f 1

      ;;

   *)
      printf 'Usage: %s stop|start ctmserver agent\n' "$(basename "$0")"
      ctmapi_logout
      exit 1
      ;;
esac

ctmapi_logout
exit 0

