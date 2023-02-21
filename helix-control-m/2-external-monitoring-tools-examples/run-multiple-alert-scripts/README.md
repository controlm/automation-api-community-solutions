## Description

The External Alert Management service from BMC Helix Control-M Automation API allows to define a script to trigger each time an alert is received (via the [**run alerts:listener:script::set**](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alerts_listener_script_set) service).

This shell script ([**run_multiple_alert_scripts.sh**](run_multiple_alert_scripts.sh)) can be useful if it is required to run more than one script for each received alert (e.g. for integration with multiple external tools). It is executed each time an alert is received and triggers all scripts in a predefined path, passing all parameters received to each of them.

## Instructions

- Update the **alert_scripts_dir** variable in the script with the path to the directory which stores your custom scripts.

## Additional information

- The scripts are executed as background processes.

- In this example, only scripts in the defined path with the ".sh" extension are executed.

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2023-02-03 | David Fernández | First release |