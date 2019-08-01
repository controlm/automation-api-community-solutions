#!/bin/bash

# Print usage and exit
print_usage() {
    printf "Usage: %s -e ENDPOINT -u USERNAME -p PASSWORD -r REPORTNAME -f [pdf|csv] [-o <file_path>]\n" "$(basename "$0")"
    exit 1
}

# logout function to be called before each exit when we're already logged in
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
reportName=""
reportFormat=""

# Check for switches
outputDirectory=""
while getopts ":e:u:p:r:f:o:" opt; do
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
      r)
          reportName=$OPTARG
          ;;
      f)
          reportFormat=$OPTARG
          ;;
      o)
          outputDirectory=$OPTARG
          ;;
     \?)
          echo "ERROR: Invalid option "
          print_usage
          ;;
      :)
          echo "-$OPTARG requires an argument"
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

# Basic sanity check for arguments

# Check if reportname set
if [[ $reportName = "" ]]; then
   printf "ERROR: report name not set ith -r\n"
   print_usage
fi

# Convert spaces in report name to %20
reportName=$(echo $reportName | sed 's/ /%20/g')

# Check report format
case $reportFormat in
   pdf|PDF)
      reportFormat="pdf"
      ;;
   csv|CSV)
      reportFormat="csv"
      ;;
   *)
      reportFormat="csv"
   ;;
esac

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
	exit 1
fi

# Generate Report
getReportURL=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/reporting/report/${reportName}?format=${reportFormat}")
if [[ ${getReportURL} == *reportURL* ]]; then
   reportURL=$(echo ${getReportURL##*reportURL\" : \"} | cut -d '"' -f 1)
   printf "reportURL=%s\n" "${reportURL}"
else
   printf "ERROR: report generation failed!\n"
   printf "%s" ${getReportURL}
   ctmapi_logout
   exit 1
fi


# Download Report
wget --no-check-certificate --directory-prefix=${outputDirectory} "${reportURL}"

ctmapi_logout
exit 0
