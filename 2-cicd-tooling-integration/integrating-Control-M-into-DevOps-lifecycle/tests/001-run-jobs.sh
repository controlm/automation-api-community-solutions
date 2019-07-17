#!/bin/bash
endpoint=$ENDPOINT
username=$CONTROLM_CREDS_USR
password=$CONTROLM_CREDS_PSW

echo "{\"username\":\"$username\",\"password\":\"$password\"}"

# Login
echo "Logging in"
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *error* ]]; then
    echo 'Login failed!'
    exit 1
fi
token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)

# Test - run the jobs
echo "Running test jobs"
curl -k -s -H "Authorization: Bearer $token" -X POST -F "definitionsFile=@../ctmjobs/MFT-conn-profiles.json" "$endpoint/deploy"
submit=$(curl -k -s -H "Authorization: Bearer $token" -X POST -F "jobDefinitionsFile=@../ctmjobs/jobs.json" "$endpoint/run")
runid=$(echo ${submit##*runId\" : \"} | cut -d '"' -f 1)

# Check job status
jobstatus=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/run/status/$runid")
status=$(echo ${jobstatus##*status\" : \"} | cut -d '"' -f 1)

echo "Waiting for jobs to end"
# Wait until jobs have finished running
until [[ $status == Ended* ]]; do
    sleep 10
    tmp=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/run/status/$runid")
    echo $tmp | grep 'Not OK' >/dev/null && exit 2
    tmp2=$(echo ${tmp##*$'\"type\" : \"Folder\",\\n'})
    status=$(echo ${tmp2##*\"status\" : \"} | cut -d '"' -f 1)
done

# Logout
curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"

# Exit
if [[ $status == *Not* ]]; then
    echo 'Job failed!'
    exit 1
else
    echo 'Success'
    exit 0
fi
