# Control job load on SAP landscape

## Requirement

Customer SAP landscapes can occassionally encounter performance issues due to various activities such as system maintenace, month-end, and other routine processes.
When this happens it can affect the execution of critical jobs or user session response times due to lack of system resources or dialog processes.  One part of the 
solution is to allow SAP administator the ability to adjust the workload coming from Control-M Workload Automation.  The Control-M adminstrator already has policies in 
place but wants to allow the SAP administors to activate or deactivate specific Workload Polices without engaging Control-M administrators each time. Also monitoring 
tools already in place can dyanamically adjust the workload load as needed.

![Script flow](./images/work-load-1.png)

## Prerequisites

A Control-M userid has been created named “sapadmin” with the following attributes:
* Assigned Roles: BrowseGroup
* Privileges > Control-M Configuration Manager: Full
* Privileges > Configuration: Update for
Workload Policies pre-defined by Control-M Administrator

## Implementation
The script will support 3 actions:

### Get
The “get” action will list current Workload Policy definitions details.

### Start
The “start” action will activate specified Workload Policy.

### Stop
The “stop” action will deactivate specified Workload Policy.

## Table of Contents

1. [scripts](./scripts)
