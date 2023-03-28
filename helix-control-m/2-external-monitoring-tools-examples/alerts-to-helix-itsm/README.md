# Helix Control-M Alerts to Remedy ITSM

## Description

Helix Control-M Alerts to Remedy ITSM

## Pre requisites

* Users will need to be familiar with the
  * [External Alerts](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alert_managementExternalAlertManagement) mechanism of the Helix Control-M platform
  * [Control-M Python Client](https://github.com/controlm/ctm-python-client)
  * [Remedy-py](https://github.com/dcompane/remedy-py) package and methods, if there is a need to customize the ITSM interface
  * General Python programming
  
### Python packages

1. Remedy_py

Need to install the current fork of the remedy_py package. A pull request is pending for it to be available in PyPI

   ```bash
   pip install git+https://github.com/dcompane/remedy-py
   ```

1. Control-M Python Client

   ```bash
   pip install ctm-python-client
   ```

   Control-M Python Client documentation is available at <https://controlm.github.io/ctm-python-client/>

1. Other packages

   * dotenv

      ```bash
      pip install python-dotenv
      ```

### BMC Helix Control-M

* Helix Control-M
* Automation API CLI

> NOTE: It has not been tested with on-prem systems, but it should work with the proper fields file (as per the documentation on the [Alerts template reference](https://docs.bmc.com/docs/display/ctmSaaSAPI/Alerts+Template+reference))

### BMC Helix ITSM

BMC Helix Remedy ITSM or on-prem with REST APIs enabled.

* Tested with version BMC Helix ITSM 20.08

## Features

* Authentication
  * only Username and password has been developed.
    * The token generated will be expired (logout) at the end of the script.
  * Unaware at this time if there are other methods possible, but reach out if you need other methods (OAuth, etc.)
* The script
  * will add the log and output to the ticket if configured on the config file (tktvars.json)
  * does not include updates to the ticket.
    * As of the BMC Helix Control-M October 2022 version, there is no API to update tickets (estimated for June 2023)
    * When available, special care will be needed for feedback loops as ticket updates will trigger an updated alert to the script.
  * will compose a URL for the case to display, if the alert is that of a job.
  * There is a feature for those that want to send an email.
    * If you want to send an email and not the ticket, you will need to comment all lines that send the ticket and ensure variables set at the return are not used in messages later.

## How to use it

### Installation

* Clone this repository

* Install the Automation API CLI in the system you will employ to receive the alerts and process them to forward to Helix ITSM.

### Configuration

* Modify your tktvars.json with the information requested in the file, appropriate for your environment
  * You will need credentials and connectivity information from both Helix Control-M and Helix ITSM

* Make your Helix Control-M necessary configurations using the CTM CLI or the scripts in the resources directory

* Test and modify the script as you see necessary. Please remember that this is __*NOT*__ a BMC supported product.

## In a nutshell

### What you need

* A user account with the AAPI ctm client installed
* the appropriate token to invoke the alert listener
* if you also want to query the Helix Control-M platform to augment the alert information, the token needs to have the appropriate roles.
* The listener will have to be able to connect to the Helix Control-M Platform.
* Start the listener as a service, with automatic restart. (See [this](alerts-to-RemedyITSM/resources/ctmalerts.service) example for Linux )
* A script that processes the alert and does something (create ticket, update ticket, email, etc.)

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

5. Enable External Alerts on BMC Helix Control-M seetings

Work via the Web interface, or use the config service.

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

### Resources

The [resources](resources) files contain SAMPLE scripts that can be used for initialization and management of the alerts. The names and content should be self-explanatory, so please open an issue if you have questions.

While they are samples, they work on my test systems.

#### Linux

The files and scripts allow to not having to memorize the commands.

* NOTE: The [ctmalerts.service](resources\Linux\ctmalerts.service) file can be used to set the listener as a Linux service. Ensure you work with your Linux Administrator to set the file properly
* You could also run the listener_monitor.sh on a cron job if you wanted additional verifications. See the script for instructions on setting up the crontab

#### Windows

The files and scripts allow to not having to memorize the commands.  

Some comments:

* Create a service using [WinSW](https://github.com/controlm/automation-api-quickstart/blob/master/helix-control-m/302-external-monitoring-tools-example/WindowsService.md): The [alerts_listener.xml](resources\Windows\alerts_listener.xml) is a working sample of how to create the service.
  *Note that the start option contains a "true" option to run the listener in forground (Attached), as per the [documentation](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alerts_listener_startrunalerts:listener::start).
* You could also run the listener_monitor.bat on a cron job if you wanted additional verifications. See the script for instructions on setting up the crontab
* Other scripts in the directory are for general management and should self explanatory.

## Do you want to contribute?

## Changes on this version

| Date | Who | What |
| - | - | - |
| 2023-02-09 | Daniel Companeetz | First release |
| 2023-03-03 | Daniel Companeetz | Readme Changes |
| 2023-03-30 | Daniel Companeetz | Multiple commits |

## Recognition

* The ones below help on the good outcomes.(no particular order!)
* The bad ones are me to blame for!

| Date | Who | What |
| - | - | - |
| 2023-02-09 | Carin Sinclair | Provided knowledge and made ITSM system available for tests |
| 2023-02-09 | Cecilia Lasecki | Helped with setting up BMC Demo Cloud instances |
| 2023-02-09 | Enrique Perez del Razo | Provided knowledge and made ITSM system available for tests |
| 2023-02-09 | Marta Zamorano Justel | Helped with setting up BMC Demo Cloud instances |
| 2023-02-09 | Wendel Bordelon | Sanity Check (hard work!) and suggestions for improving the ticket content |

## Contributions

| Date | Who | What |
| - | - | - |
|  |  |  |

### Do you want to contribute?

All contributions are welcome to improve and augment this work as per the [Contribution Guidelines](https://github.com/controlm/automation-api-community-solutions#contribution-guide)

If you have questions or comments about this sub-project, please use the [BMC Community](https://community.bmc.com/s/topic/0TO3n000000Wdn1GAC/bmc-helix-controlm), and ensure to tag your entry with the BMC Helix Control-M tag.

## Who is using it

| Date | Who | Notes |
| - | - | - |
|  | |  |
