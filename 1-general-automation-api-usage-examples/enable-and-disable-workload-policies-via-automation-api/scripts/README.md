# enable-disable-workload-policy.sh

This directory contains 1 example script:
* [enable-disable-workload-policy.sh](./enable-disable-workload-policy.sh)

This script enables authorized Control-M users to get of list of Workload Policies, activate, and deactivate them.  The Control-M admin can create several
rules to support multiple conditions.  For example, the admin can create "sap-stop-all","sap-multi-30", and "sap-multi-100" to stop all SAP jobs, allow 30 to run concurrently,
or 100 jobs to run concurrently.

The script provides 3 functions {get , stop, start} which correlate to the 3 functions.  The name of the rule should be entered in quotes to avoid issue with spaces and special 
characters in the name"

The below examples follow the Bash shell script but can be applied to other scripting languages.

### How to use
To use the script set the variables at the script entry to approprivate values for your environment.
```
endpoint="https://wla919:8443/automation-api"
username="sapadmin"
password="sapadminpassword"
```
To get a list of pre-defined WorkLoad Policy rules:
```
./enable-disable-workload-policy.sh get
```
To activate a pre-defined Workload Policy rule:
```
./enable-disable-workload-policy.sh start "<rule>"
```
To de-activate a pre-defined Workload Policy rule:
```
./enable-disable-workload-policy.sh stop "<rule>"
```


### Table of Contents
1. [enable-disable-workload-policy.sh](./enable-disable-workload-policy.sh)
2. [script walkthrough](./enable-disable-workload-policy-README.md)