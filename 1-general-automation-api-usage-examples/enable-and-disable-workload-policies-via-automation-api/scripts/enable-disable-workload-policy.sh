#!/bin/bash

#Update these variables with appropriate values for your environment
endpoint="https://wla919:8443/automation-api"
username="sapadmin"
password="sapadminpassword"

#logout function to be called before each exit when we're already logged in
ctmapi_logout () {
  curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"  > /dev/null
}


# Check script arguments
if [[ ! $# -ge 1 ]] ; then
    printf 'Usage: %s get|stop|start "WorkLoad Rule"\n' "$(basename "$0")"
    exit 1
fi

workLoadRule=$(echo $2 | sed 's/ /%20/g')

# Login to Control-M API
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *token* ]] ; then
	token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)
else
	printf "Login failed!\n"
	exit 1
fi

case $1 in
   get)
      # Get list of Workload Policies
      curl -k -H "Authorization: Bearer $token" -X GET "$endpoint/run/workloadpolicies"
      exit 0
      ;;
   stop)
      if [ ! "$2" ]; then
         printf "No Workload Rule specified.\n"
         exit 1
      fi
 
      printf "Deactivating '%s' \n" "$2"
      # Enable Workload Policy
      curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X POST "$endpoint/run/workloadpolicy/${workLoadRule}/deactivate"
      ;;
   start)
      if [ ! "$2" ]; then
         printf "No Workload Rule specified.\n"
         exit 1
      fi
 
      printf "Activating '%s' \n" "$2"
      # Enable Workload Policy
      curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X POST "$endpoint/run/workloadpolicy/${workLoadRule}/activate"
      ;;

   *)
    printf 'Usage: %s get|stop|start "WorkLoad Rule"\n' "$(basename "$0")"
      ctmapi_logout
      exit 1
      ;;
esac

ctmapi_logout
exit 0

