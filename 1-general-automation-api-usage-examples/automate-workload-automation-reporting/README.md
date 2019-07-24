# Automate Workload Automation Reporting

## Requirement
Starting with Control-M/Enterprise Manager 9.0.18 the reporting engine was changed to a web based implementation.  As a result legacy tools such as "emreportcli"
are no longer compatible with Control-M/Enterprise Manager. In their place is a new modern interface based on REST services to interact with the reporting
server.  Control-M Automation API exposes verbs to generate and retrieve reports synchronously and asynchronously.  There are various methods to invoke the REST calls.
The Operations team has requested a simple bash script they could execute on Unix environments to be used by various teams and customers with minimal installation
requirements.

## Prerequisites
* Automation APi 9.0.18.300 and below.
* Assigned Roles: BrowseGroup
* Privileges > Control-M Configuration Manager: Full
* Privileges > Monitoring and Administration Tools > CLI: Full
* Unix system with curl

## Implementation

![Script flow](./images/automate-report-1.png)

## Limitations

* To generate a report through the Control-M Automation API, the user running the command must be the same as the Control-M/EM user who created the report in Control-M Reports.


## Table of Contents

1. [scripts](./scripts)

