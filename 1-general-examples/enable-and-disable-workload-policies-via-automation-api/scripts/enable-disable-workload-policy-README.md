#### enable-disable-workload-policy.sh walkthrough

## Print basic usage and exit
```
print_usage()
```
## Logout function
A logout function is defined which can be easily called before any `exit` call
made in the script. This is to make the code more readable.
```
curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"
```

## Login
First, a login to Control-M is performed, and the session token is captured:
```
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *token* ]] ; then
	token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)
```

The session token is needed for all subsequent calls to Control-M.

## Get Workload Policy Definitions

This retrieves all the Workload Policy definitions from Control-M in json format.
To active or deactive a rule specify the "name" value in the start or stop options.

```
curl -k -H "Authorization: Bearer $token" -X GET "$endpoint/run/workloadpolicies"
```

## Start Workload Policy
This starts a specifed Workload Policy.
```
curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X POST "$endpoint/run/workloadpolicy/${workLoadRule}/activate"
```

## Stop Workload Policy
This stops a specifed Workload Policy.
``` 
curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X POST "$endpoint/run/workloadpolicy/${workLoadRule}/deactivate"
```

## Table of Contents
* [Main README](../README.md)
* [enable-disable-workload-policy.sh](./enable-disable-workload-policy.sh)
* [script walkthrough](./enable-disable-workload-policy-README.md)