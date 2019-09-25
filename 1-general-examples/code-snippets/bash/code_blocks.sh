#! /bin/bash

for i in "$@"
do
case $i in
    -pf=*|--password-file=*)
    pwfile="${i#*=}"
    shift # past argument=value
    ;;
    -u=*|--username=*)
    username="${i#*=}"
    shift # past argument=value
    ;;
    -h=*|--host=*)
    endpoint="https://${i#*=}:8443/automation-api"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

if [[ ! -z $pwfile ]]; then
  password=$(cat $pwfile)
else
  echo -n "Password: "
  read -s password
  echo ""
fi

login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )

RC=$?
if [[ $RC -ne 0 ]]; then
  echo "Login request failed"
  exit 5
fi

echo "$login" | grep "errors" > /dev/null && echo "Failed to login" && exit 5

echo "Login Succeeded"
