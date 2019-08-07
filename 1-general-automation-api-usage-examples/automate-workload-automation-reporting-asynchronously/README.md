# Automate Workload Automation Reporting Asynchronously

## Requirement

Starting with Control-M/Enterprise Manager 9.0.18 the reporting engine was changed to a web based implementation.  The various teams can generate reports via 
the Control-M Reports client, Automation API 'ctm' utility, and direct REST calls but there are times when the reports take many minutes to complete.  They request the option 
to run the reports without having to wait for them to complete so they don't have to leave it running on their workstations.  Also the sychronous option will soon be deprecated.

## Prerequisites
* Control-M/Enterprise Manager 9.0.19+
* Automation API 9.0.19+
* Report defined in Control-M Reports
* Control-M user with the following *minimal* privileges:
    * Assigned Roles: BrowseGroup
    * Privileges > Control-M Configuration Manager: Full
    * Privileges > Monitoring and Administration Tools > CLI: Full
* Unix system with bash, curl and wget

## Implementation

![Script flow](./images/automate-report-asynch-1.png)

The script uses the following [Automation API Reporting service](https://docs.bmc.com/docs/automation-api/919110/reporting-service-872868767.html) commands:
* [reporting report](https://docs.bmc.com/docs/automation-api/919110/reporting-service-872868767.html#Reportingservice-reportAsyncAsynchronousreportgeneration(reportingreport)) 
* [reporting status::get](https://docs.bmc.com/docs/automation-api/919110/reporting-service-872868767.html#Reportingservice-reportStatusGetGetreportstatus(reportingstatus::get))


## Table of Contents

1. [scripts and documentation](./scripts)




