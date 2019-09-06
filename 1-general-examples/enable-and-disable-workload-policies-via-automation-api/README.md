# Control job load on SAP landscape

## Requirement

Customer SAP landscapes can occassionally encounter performance issues due to various activities such as system maintenace, month-end, and other routine processes.
When this happens it can affect the execution of critical jobs or user session response times due to lack of system resources or dialog processes.  One part of the 
solution is to allow SAP administator the ability to adjust the workload coming from Control-M Workload Automation.  The Control-M adminstrator already has policies in 
place but wants to allow the SAP administors to activate or deactivate specific Workload Polices without engaging Control-M administrators each time. Also monitoring 
tools already in place can dyanamically adjust the workload load as needed.

![Script flow](./images/work-load-1.png)

## Prerequisites

* Control-M/Enterprise Manager 9.0.19 or higher
* Control-M/Automation API 9.0.19 or higher
* A Control-M userid with the following minimal privileges:
    * Assigned Roles: BrowseGroup
    * Privileges > Control-M Configuration Manager: Full
    * Privileges > Configuration: Update for Workload Policies 
* Workload Policies pre-defined by Control-M Administrator
* Unix system with bash shell and curl

## Implementation
The script will support 3 actions.  When no actions are specified the "get" will be performed.

### Get
The “get” action will list current Workload Policy definitions details.

### Start
The “start” action will activate specified Workload Policy.

### Stop
The “stop” action will deactivate specified Workload Policy.

## The bash script uses the following Automation API [run service](https://docs.bmc.com/docs/automation-api/919/services-817914516.html#Services-Run_ServiceTheRunService) commands:
* [run workloadpolicies::get](https://docs.bmc.com/docs/automation-api/919/services-817914516.html#Services-wp_getrunworkloadpolicies::get)
* [run workloadpolicy::activate](https://docs.bmc.com/docs/automation-api/919/services-817914516.html#Services-wp_actrunworkloadpolicy::activate)
* [run workloadpolicy::deactivate](https://docs.bmc.com/docs/automation-api/919/services-817914516.html#Services-wp_deactrunworkloadpolicy::deactivate)

## Video

The following video demonstrates the above steps.

[![Video Demo Link](./images/work-load-2.png "Video Demo on YouTube")](https://youtu.be/oVli_4fRRvQ)

Click the above image to watch the video on YouTube.

## Table of Contents
* [Scripts and Documentation](./scripts)
