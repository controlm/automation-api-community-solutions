# enable-disable-workload-policy.sh

The enable-disable-workload-policy.sh script allows a Control-M user to list, activate, and deactivate Workload Policies assigned to them.

This directory contains 1 example script:
* [enable-disable-workload-policy.sh](./enable-disable-workload-policy.sh)

This script enables authorized Control-M users to get of list of Workload Policies, activate, and deactivate them.  The Control-M admin can create several
rules to support multiple conditions.  For example, the admin can create "sap-stop-all","sap-multi-30", and "sap-multi-100" to stop all SAP jobs, allow 30 to run concurrently,
or 100 jobs to run concurrently.

The script provides 3 functions {get , stop, start} which correlate to the 3 functions.  The name of the rule should be entered in quotes to avoid issues with spaces and special 
characters in the name.

The below examples follow the Bash shell script but can be applied to other scripting languages.

## How to use
Usage
```
Usage: enable-disable-workload-policy.sh -e ENDPOINT -u USERNAME -p PASSWORD [ -get | -stop "WorkLoad Rule" | -start "WorkLoad Rule" ]
```
To get a list of pre-defined WorkLoad Policy rules:
```
./enable-disable-workload-policy.sh -e ENDPOINT -u USERNAME -p PASSWORD -get
```
To activate a pre-defined Workload Policy rule:
```
./enable-disable-workload-policy.sh -e ENDPOINT -u USERNAME -p PASSWORD -start "<rule>"
```
To de-activate a pre-defined Workload Policy rule:
```
./enable-disable-workload-policy.sh -e ENDPOINT -u USERNAME -p PASSWORD -stop "<rule>"
```

## Examples
### Get available Workload Policies
```
./enable-disable-workload-policy.sh -e https://wla919:8443/automation-api -u sapadmin -p sapadminpassword -get
{
  "workloadPolicies" : [ {
    "name" : "sap-stop-all",
    "state" : "Inactive",
    "orderNo" : "2",
    "lastUpdate" : "20190806222001",
    "updatedBy" : "sapadmin (data), emuser (filter)",
    "description" : "stop all SAP jobs"
  }, {
    "name" : "sap-multi-100",
    "state" : "Inactive",
    "orderNo" : "5",
    "lastUpdate" : "20190806221400",
    "updatedBy" : "emuser (data), emuser (filter)",
    "description" : "allow 100 max jobs, basically unlimited"
  }, {
    "name" : "sap-multi-30",
    "state" : "Inactive",
    "orderNo" : "6",
    "lastUpdate" : "20190806221206",
    "updatedBy" : "emuser (data), emuser (filter)",
    "description" : "allow 30 max jobs"
  } ]
}
```
### Active a Workload Policy
```
./enable-disable-workload-policy.sh -e https://wla919:8443/automation-api -u sapadmin -p sapadminpassword -start "sap-stop-all"
Activating 'sap-stop-all'
{
  "workloadPolicies" : [ {
    "name" : "sap-stop-all",
    "state" : "Successfully activated"
  } ]
```
### De-activate a Workload Policy
```
./enable-disable-workload-policy.sh -e https://wla919:8443/automation-api -u sapadmin -p sapadminpassword -stop "sap-stop-all"
Deactivating 'sap-stop-all'
{
  "workloadPolicies" : [ {
    "name" : "sap-stop-all",
    "state" : "Successfully deactivated"
  } ]
```

## Table of Contents
* [Main README](../README.md)
* [enable-disable-workload-policy.sh](./enable-disable-workload-policy.sh)
* [script walkthrough](./enable-disable-workload-policy-README.md)