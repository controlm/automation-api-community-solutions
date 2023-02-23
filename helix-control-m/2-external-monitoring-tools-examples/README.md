# BMC Helix Control-M API - External Monitoring Tools Examples

This folder contains sample scripts that can be used to transfer alerts to external tools, such as an event management system or a monitoring solution.

## Description

An alert in BMC Helix Control-M is a message that indicates that a problem or exception has occurred (in a Job, Folder, Service, Agent, etc). The BMC Helix Control-M Automation API includes an **External Alert Management** service which, amongst other capabilities, enables triggering a script each time an alert is received. Such script can be customized for any requirements: saving alert data into a file, sending a webhook to a monitoring solution, running a command which transfers alert details to an external tool, etc.

## Documentation

Please refer to the BMC Helix Control-M documentation on [**Setting Up External Alerts**](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/Alerts.htm#SettingUpExternalAlerts) for details on how to enable the service.

The BMC Helix Control-M Automation API documentation has a section for [**External Alert Management**](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alert_managementExternalAlertManagement), which includes all the actions available to manage the stream of alerts from BMC Helix Control-M and configure the listener process on your client.

## In a nutshell

### What you need

- A user account with the AAPI ctm client installed
- the appropriate token to invoke the alert listener
- if you also want to query the Helix Control-M platform to augment the alert information, the token needs to have the appropriate roles.
- The listener will have to be able to connect to the Helix Control-M Platform.
- Start the listener as a service, with automatic restart. (See [this](alerts-to-RemedyITSM/resources/ctmalerts.service) example for Linux )
- A script that processes the alert and does something (create ticket, update ticket, email, etc.)


### Steps to implement

1. Define an environment with the token to the Helix Control-M platform

```bash
ctm environment saas::add <env> <endPoint> <token>
```

2. Set up External Alert management for environment ```<env>```

```bash
ctm run alerts:listener:environment::set <env>
```

3. Set up External Alert management script to ```<script>```

```bash
ctm run alerts:listener:script::set <script>
```

4. Set up External Alert management template to ```<fields_file>```

```bash
ctm run alerts:stream:template::set -f <fields_file>
```

5.  Enable External Alerts on BMC Helix Control-M

```bash
ctm config systemsettings::set enableExternalAlerts true
```

6. Check  External Alerts status

```bash
ctm run alerts:stream::status
```

7. If open or running somewhere else, close the External Alerts stream

```bash
ctm run alerts:stream::close true
```

8. Explicitly open the External Alerts stream

```bash
ctm run alerts:stream::open
```

9. Start the External Alerts listener

```bash
ctm run alerts:listener::start
```

10. Re-check the External Alerts status, again. Should be OK.

```bash
ctm run alerts:stream::status
```
