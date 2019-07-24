#!/bin/bash

# Update these variables with appropriate values for your environment
endpoint="https://wla919:8443/automation-api"
username="reportuser"
password="reportuserpassword"

# logout function to be called before each exit when we're already logged in
ctmapi_logout () {
  curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"  > /dev/null
}

# Check script arguments
if [[ ! $# -ge 1 ]] ; then
    printf "Usage: %s <reportname> [format] [-o <file_path>]\n" "$(basename "$0")"
    exit 1
fi

# Basic sanity check for arguments

# Convert spaces in report name to %20
reportName=$(echo $1 | sed 's/ /%20/g')

# Check report format
reportFormat=""
case $2 in
   pdf)
      reportFormat="pdf"
      shift 2
      ;;
   csv)
      reportFormat="csv"
      shift 2
      ;;
   *)
      reportFormat="csv"
      shift 1
      ;;
esac

# Check for swithes
outputDirectory=""
while getopts ":o:" opt; do
   case ${opt} in
      o)
          outputDirectory=$OPTARG
          ;;
     \?)
          echo "ERROR: Invalid option "
          exit 1
          ;;
      :)
          echo "-$OPTARG requires an argument"
          exit 1
          ;;
    esac 
done
shift $((OPTIND -1))

# Check if curl is available
curlVersion=""

getCurlVersion=$(curl --version)
if [[ ${getCurlVersion} == *Release-Date* ]]; then
   curlVersion=$(echo ${getCurlVersion##curl} | grep curl | cut -d ' ' -f2)
fi

if [ "${curlVersion}" == "" ]; then
   printf "ERROR: curl version not detected.\n"
   exit 1
fi


# Login to Control-M API and save token
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *token* ]] ; then
	token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)
else
	printf "Login failed!\n"
        ctmapi_logout
	exit 1
fi

# Generate Report
getReportURL=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/reporting/report/${reportName}?format=${reportFormat}")
if [[ ${getReportURL} == *reportURL* ]]; then
   reportURL=$(echo ${getReportURL##*reportURL\" : \"} | cut -d '"' -f 1)
   printf "reportURL=%s\n" "${reportURL}"
else
   printf "ERROR: report generation failed!\n"
   exit 1
fi


# Download Report
wget --no-check-certificate --directory-prefix=${outputDirectory} "${reportURL}"

ctmapi_logout
exit 0
