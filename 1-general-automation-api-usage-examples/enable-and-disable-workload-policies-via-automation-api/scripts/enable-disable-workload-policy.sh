#!/bin/bash

# This script is used to list, stop, and start Control-M Workload Policies

scriptname=`basename "$0"`

# Print usage and exit
print_usage() {
   printf '%s is used to list, stop, and start Control-M Workload Policies \n' $scriptname
   printf 'Usage: %s -e ENDPOINT -u USERNAME -p PASSWORD [ -get | -stop "WorkLoad Rule" | -start "WorkLoad Rule" ] \n' "$scriptname"
   exit 1
}

#logout function to be called before each exit when we're already logged in
ctmapi_logout () {
  curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"  > /dev/null
}

# Check script arguments
if [[ ! $# -ge 1 ]] ; then
    print_usage
fi

# Initialize variables
endpoint=""
username=""
password=""
# Default is get list of rules
function="get"       
rule=""


#
# Convert long switches to short for getopts
#
for arg in "$@"; do
  shift
  case "$arg" in
    "-get"|"--get")  set -- "$@" "-g" ;;
    "-stop"|"--stop") set -- "$@" "-s" ;;
    "-start"|"--start") set -- "$@" "-t" ;;
    *)set -- "$@" "$arg"
  esac
done

#
# Check for switches
#
while getopts ":e:u:p:t:s:g" opt; do
   case ${opt} in
      e)
          endpoint=$OPTARG
          ;;
      u)
          username=$OPTARG
          ;;
      p)
          password=$OPTARG
          ;;
      g)
          function="get"
          ;;
      s)
          function="stop"
          rule=$OPTARG
          ;;
      t)
          function="start"
          rule=$OPTARG
          ;;
     \?)
          printf "ERROR: Invalid option %s \n" "${OPTARG}"
          print_usage
          ;;
      :)
          if [ "${OPTARG}" == "s" ]; then 
             printf -- '-stop requires an argument \n'
          fi
          if [ "${OPTARG}" == "t" ]; then 
             printf -- '-start requires an argument \n'
          fi
          print_usage
          ;;
    esac 
done
shift $((OPTIND -1))

# Check if required parameters are set
# Check if automation api endpoint is set
if [[ $endpoint = ""  ]]; then
   printf "ERROR: endpoint not set with -e\n" print_usage
fi

# Check if username/password are not set
if [[ ( $username = "" ) ||  ( $password = "" )  ]]; then
   printf "ERROR: username or password not set with -u -p\n"
   print_usage
fi


workLoadRule=$(echo $rule | sed 's/ /%20/g')

# Login to Control-M API
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *token* ]] ; then
	token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)
else
	printf "Login failed!\n"
	exit 1
fi

case $function in
   get)
      # Get list of Workload Policies
      curl -k -H "Authorization: Bearer $token" -X GET "$endpoint/run/workloadpolicies"
      printf "\n"
      exit 0
      ;;
   stop)
      if [ ! "${workLoadRule}" ]; then
         printf "No Workload Rule specified.\n"
         exit 1
      fi
 
      printf "Deactivating '%s' \n" "${workLoadRule}"
      # Enable Workload Policy
      curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X POST "$endpoint/run/workloadpolicy/${workLoadRule}/deactivate"
      ;;
   start)
      if [ ! "${workLoadRule}" ]; then
         printf "No Workload Rule specified.\n"
         exit 1
      fi
 
      printf "Activating '%s' \n" "${workLoadRule}"
      # Enable Workload Policy
      curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X POST "$endpoint/run/workloadpolicy/${workLoadRule}/activate"
      ;;
esac

# Logout
ctmapi_logout
exit 0
