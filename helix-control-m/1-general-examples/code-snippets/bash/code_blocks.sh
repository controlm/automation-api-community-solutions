#!/bin/bash
# example shell code for starting a script to communicate with Control-M AAPI.
# reads command-line arguments, then reads API Token and sends an example API request.

ctmaapi_url='https://YOURTENANT-aapi.us1.controlm.com/automation-api'

for i in "$@"
do
case $i in
    -tf=*|--token-file=*)
    tokenfile="${i#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

# Read token from file, or if none given, ask user input
if [[ ! -z $tokenfile ]]; then
  token=$(cat $tokenfile)
else
  echo -n "API Token: "
  read -s token
  echo ""
fi


# Send the example Get Roles request (make sure the token has config authorizations)
response=$(curl -k -s -H "x-api-key: $token" -X GET "$ctmaapi_url/config/authorization/roles" )

# fail if non-zero return code
RC=$?
if [[ $RC -ne 0 ]]; then
  echo "Request failed"
  exit 1
fi

# check response for errors, fail if found
echo "$response" | grep "errors" > /dev/null && echo "Failed to login" && exit 2

echo "Get Roles Response:"
echo $response
