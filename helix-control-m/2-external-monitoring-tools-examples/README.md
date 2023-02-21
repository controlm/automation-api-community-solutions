# BMC Helix Control-M API - External Monitoring Tools Examples

This folder contains sample scripts that can be used to send Helix Control-M alerts to external applications, such as event management systems, monitoring tools or ITSM solutions.

## Description

An alert in Helix Control-M is a message that indicates that a problem or exception has occurred (in a Job, Folder, Service, Agent, etc). The Helix Control-M Automation API includes an **External Alert Management** service which, amongst other capabilities, enables triggering a script each time an alert is received. Such script can be customized for any requirements: saving alert data into a file, sending a webhook to a monitoring solution, running a command which transfers alert details to an external tool, etc.

## Documentation

Please refer to the Helix Control-M documentation on [**Setting Up External Alerts**](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/Alerts.htm#SettingUpExternalAlerts) for details on how to enable the service.

The Helix Control-M Automation API documentation has a section for [**External Alert Management**](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alert_managementExternalAlertManagement), which includes all the actions available to manage the stream of alerts from BMC Helix Control-M and configure the listener process on your client.