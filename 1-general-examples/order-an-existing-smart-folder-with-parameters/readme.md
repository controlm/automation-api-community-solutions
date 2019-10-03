# Running existing Control-M workflows
Workflows are stored in the Control-M database and can be triggered via REST api to run. Additionally, you have the ability to pass parameters into your workflow at runtime. 
[Automation API Code Reference documentation page](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Code+Reference)

## Requirement : 
I have a workflow configured in a Control-M Smart folder defined as a service and I want to order it using the aapi. I also want to pass parameters at the time of ordering.

## Prerequisite : Have a workflow defined in a Smart folder and a Service definition with orderable parameters
Solution : Use the ctm run order call

Syntax :

```ctm run order <ctm> <folder> [jobs] [-f <configuration file> -i]```

Sample : 

```ctm run order CONTROLMNAME MYFOLDERNAME -f JSONconfigfile.json```

## OPTIONS Explained
<ctm> is the control-m server name
<folder> is the smart folder name being ordered
[jobs] is optional if you want to order specific jobs from the smart folder
-f is a json file containing arguments

## Perform a rest call from e.g. a script as alternative 

In some cases, you might not need the full cli. E.g. a lighter option might be preferred if an external application needs to trigger a worklaod on Control-M. In such scenario, a REST call might be the preferred opion. The REST example is described on the [Automation API Service Reference documentation](https://docs.bmc.com/docs/automation-api/9019100monthly/run-service-872868748.html#Runservice-runorder)

An example implementation of of this REST api can by found in the ctm_order.py script. This script can be used stand-alone and does not need the Automation API CLI or NodeJs installend.

usage: ctm_order.py [-h] -e ENDPOINT -s CTM_SERVER -u USER -p PASSWORD
                    --folder FOLDER [--config_file CONFIG_FILE] [-v]
                    [--version]

Orders an adhoc job in Control-M for the folder specified

optional arguments:
  -h, --help            show this help message and exit
  -e ENDPOINT, --endpoint ENDPOINT
                        Control-M Automation API end-point for connecting with
                        Control-M
  -s CTM_SERVER, --ctm_server CTM_SERVER
                        Control-M Server name
  -u USER, --user USER  Control-M user name for connecting with Control-M
  -p PASSWORD, --password PASSWORD
                        Control-M password for connecting with Control-M
  --folder FOLDER       Control-M folder name which holds the jobs to be
                        ordered
  --config_file CONFIG_FILE, -f CONFIG_FILE
                        A json file that holds additional configuration
                        parameters
  -v, --verbose         Enables verbose mode
  --version             show program's version number and exit

# Example JSON config file

```
{
  "variables": [{"variablename":"variablevalue"}],
  "ignoreCriteria": "true",
  "orderIntoFolder": "New"
}
```

All the default options look like this 

```
{
  "variables": [{"arg":"12345"}],
  "hold": "true",
  "ignoreCriteria": "true",
  "independantFlow": "false",
  "orderDate": "20170903",
  "waitForOrderDate": "false",
  "createDuplicate": "false",
  "orderIntoFolder": "Recent"
}
```



