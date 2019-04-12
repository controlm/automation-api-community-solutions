# Running existing Control-M workflows
Workfl ows are stored in the Control-M database and can be triggered via REST api to run. Additionally, you have the ability to pass parameters into your workflow at runtime. 
[Automation API Code Reference documentation page](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Code+Reference)

## Requirement : 
I have a workflow configured in a Control-M Smart folder defined as a service and I want to order it using the aapi. I also want to pass parameters at the time of ordering.

## Prerequisite : Have a workflow defined in a Smart folder and a Service definition with orderable parameters
Solution : Use the ctm run order call

Syntax :

```ctm run order <ctm> <folder> [jobs] [-f <configuration file> -i]```

Sample : 

```ctm run order CONTROLMNAME MYFOLDERNAME -f JSONconfig.json```

## OPTIONS Explained
<ctm> is the control-m server name
<folder> is the smart folder name being ordered
[jobs] is optional if you want to order specific jobs from the smart folder
-f is a json file containing arguments

# Example JSON config file

```
{
  "variables": [{"webserver":"neilfromconfigfile"}],
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

