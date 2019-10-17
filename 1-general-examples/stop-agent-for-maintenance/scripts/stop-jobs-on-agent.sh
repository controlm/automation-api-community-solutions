#!/bin/bash
#------------------------------------------------------------------------------------
#	Stop scheduling jobs to a host during maintenance 
#------------------------------------------------------------------------------------
endpoint=https://EMSERVER:8443/automation-api
username=sysadmin
password=$(cat .authfile)  #password stored in file .authfile
maxiterations=300   # number of iterations the script will check if jobs are still running
sleepinterval=1    # number of seconds between each check interval

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
	printf "%s\n" "$login"
	printf "Login failed!\n"
	exit 1
fi

# Selected action is start or stop
case $1 in
   stop)
      # Check if Agent exists
      agents=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/config/server/$ctmserver/agents?agent=$agenthost")
      if [[ $agents == '{ }' ]] ; then
         printf "No Agent named \"%s\" found in Control-M/Server \"%s\"" "$agenthost" "$ctmserver"
         ctmapi_logout
         exit 1
      fi

      # Check if jobs are still running on the Agent
      i=0
      result=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/run/jobs/status?host=$agenthost&status=Executing")
      returned=$(echo ${result##*returned\" : } | cut -d ',' -f 1)
      until [[ $returned -eq 0 || $i -gt $maxiterations ]]; do
         #below 4 lines only used to display moving status indicator
         if [ $((i%4)) -eq 0 ]; then ind='-' ; fi
         if [ $((i%4)) -eq 1 ]; then ind='\' ; fi
         if [ $((i%4)) -eq 2 ]; then ind='|' ; fi
         if [ $((i%4)) -eq 3 ]; then ind='/' ; fi

         printf " %s jobs still executing on agent %s... %s\r" "$returned" "$agenthost" "$ind"
         sleep $sleepinterval

         result=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/run/jobs/status?host=$agenthost&status=Executing")
         returned=$(echo ${result##*returned\" : } | cut -d ',' -f 1)
         i=$((i+1))
      done

      if [[ $returned > 0 ]]; then
         printf "\nContact Control-M administrator to check the jobs running on Agent %s.\n" "$agenthost"
         ctmapi_logout
         exit 1
      else 
         printf "\rNo jobs running on %s. Disabling the Agent...\n" "$agenthost"

         # Disable the Agent
         result=$(curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/config/server/$ctmserver/agent/$agenthost/disable")
         echo ${result##*message\" : \"} | cut -d '"' -f 1
      fi
      ;;

   start)
      # Disable the Agent
      result=$(curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/config/server/$ctmserver/agent/$agenthost/enable")
      echo ${result##*message\" : \"} | cut -d '"' -f 1
      ;;

   *)
      printf "second parameter must be either  stop  or  start\n"
      printf "Usage: %s stop|start ctmserver agent\n" "$(basename "$0")"
      ctmapi_logout
      exit 1
      ;;
esac

ctmapi_logout
exit 0

