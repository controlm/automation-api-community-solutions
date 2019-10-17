# scripts

This directory contains two example scripts:
* [stop-jobs-on-agent.ps1](./stop-jobs-on-agent.ps1)
* [stop-jobs-on-agent.sh](./stop-jobs-on-agent.sh)

The below examples follow the **Stop** job flow of the Bash shell script, 
however the PowerShell script calls the same Control-M Automation API functions 
and has an identical program flow.

### Logout function
A logout function is defined which can be easily called before any `exit` call
made in the script. This is to make the code more readable.
```
curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"
```

### Login
First, a login to Control-M is performed, and the session token is captured:
```
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *token* ]] ; then
	token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)
```

The session token is needed for all subsequent calls to Control-M.

### Get Agent list
Next, a call is made to retrieve the list of Agents matching the name given by 
the user. This is to check if an Agent by that name actually exists.
```
agents=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/config/server/$ctmserver/agents?agent=$agenthost")
```


### Check if jobs are still running on the Agent
The script now calls the following API in a loop to determine if any jobs are 
still in Executing status on the Agent. 
```
result=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/run/jobs/status?host=$agenthost&status=Executing")
```
The check is perfomed for a maximum of 5 minutes (configurable). If no jobs are 
found to be running, the Agent id disabled in the next step. Else, if jobs are
still running after waiting for 5 minutes, the user is asked to contact a 
Control-M administrator.


### Disable the Agent
If all is well to this point, the actual call is made to disable the Agent. 
This toggles the Agent to being unavailable for any jobs that want to run in 
Control-M. After this call runs succesfully, no more jobs will be started on
this host by Control-M.
```
result=$(curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/config/server/$ctmserver/agent/$agenthost/disable")
```


### Powershell storing of login credentials

The Powershell version of the script uses the ConvertTo-SecureString cmdlet 
to store the AAPI login password encrypted in a file.  The script `storepass.ps1`
is provided to store the password in a file.
