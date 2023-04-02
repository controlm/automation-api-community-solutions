# BMC Helix Control-M API - External Monitoring Tools Examples

This folder contains sample scripts that can be used to transfer alerts to external tools, such as an event management system or a monitoring solution.

## Description

An alert in BMC Helix Control-M is a message that indicates that a problem or exception has occurred (in a Job, Folder, Service, Agent, etc). The BMC Helix Control-M Automation API includes an **External Alert Management** service which, amongst other capabilities, enables triggering a script each time an alert is received. Such script can be customized for any requirements: saving alert data into a file, sending a webhook to a monitoring solution, running a command which transfers alert details to an external tool, etc.

## Documentation

Please refer to the BMC Helix Control-M documentation on [**Setting Up External Alerts**](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/Alerts.htm#SettingUpExternalAlerts) for details on how to enable the service.

The BMC Helix Control-M Automation API documentation has a section for [**External Alert Management**](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alert_managementExternalAlertManagement), which includes all the actions available to manage the stream of alerts from BMC Helix Control-M and configure the listener process on your client.
