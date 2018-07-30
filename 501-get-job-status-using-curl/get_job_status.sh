#!/bin/bash

# Version 1.0
# Created by Tijs Monté
# Created on 30-July-2018
# 
# Purpose: Fetch the status of folders and jobs filtered by application or use "*" for all applications.
# Output can be printed to stdout or to a file specified

if [ -z "$1" ]; then
   echo "Error: Missing parameters"
   echo ""
   echo "Usage get_job_status <endpoint> <username> <password> <application> <outputfile>"
   echo ""
   echo "endpoint       : https://<hostname>:8443/automation-api"
   echo "user           : Control-M user name"
   echo "password       : Control-M password"
   echo "application    : name of the applition or \"*\""
   echo "outputfile     : file to store the output (optional)"
   echo ""
   exit 1
fi


 
# Setting the variables
endpoint=$1				# https://<hostname>:8443/automation-api
user=$2					# Control-M user name
passwd=$3				# Control-M password
output_file=$5			# File to store output.
curl_parms=-k		

# Login
echo "==============================================================================="
echo "==============================================================================="
echo "============                                                       ============"
echo "============                 START GET JOB STATUS                  ============"
echo "============                                                       ============"
echo "==============================================================================="
echo "==============================================================================="

echo -e "\n============ $(date +"%Y-%m-%d %T") Login\n"

login=$(curl $curl_parms -H "Content-Type: application/json" -X POST -d "{\"username\":\"$user\",\"password\":\"$passwd\"}"   "$endpoint/session/login" )
token=$(expr "$login" : '.*"token" : "\([^"]*\)"')


if [ -z "$token" ]; then
   echo -e "\n============ $(date +"%Y-%m-%d %T")  Authentication failed"
   echo -e "============ $(date +"%Y-%m-%d %T")  Login result:\n\n $login"
   echo -e "\n============ $(date +"%Y-%m-%d %T")  Using token:\n\n $token"
   exit 1
else
   echo -e "\n============ $(date +"%Y-%m-%d %T")  Authentication passed"
   echo -e "============ $(date +"%Y-%m-%d %T")  Login result:\n\n $login"
   echo -e "\n============ $(date +"%Y-%m-%d %T")  Using token:\n\n $token"
    
   # Build a Control-M workflow with curl usinig a JSON input file

   if [ -z $5 ]; then
      echo -e "\n============ $(date +"%Y-%m-%d %T")  Fetching output for application $4 to stdout\n" 
      curl $curl_parms -H "Authorization: Bearer $token" "$endpoint/run/jobs/status?application=$4"
   else
      echo -e "\n============ $(date +"%Y-%m-%d %T")  Fetching output for application $4 into file $5\n"
      curl --output $5 $curl_parms -H "Authorization: Bearer $token" "$endpoint/run/jobs/status?application=$4"
   fi

   # Logout
   # Session Logout to invalidate API session token
   echo -e "\n============ $(date +"%Y-%m-%d %T") Logout\n"
   curl $curl_parms -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"
   
   echo -e "\n\n===================================== END ====================================="
   echo "==============================================================================="
   
exit 0
fi
