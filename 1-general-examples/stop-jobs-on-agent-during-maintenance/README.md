# Stop scheduling jobs to a host during maintenance

## Requirement

During system maintenance outages on weekends, for example when the sysadmins 
need to apply operating system patches, a Control-M admin needs to be on the
call to stop jobs from being scheduled to that agent before maintenance can 
start and enable scheduling again afterwards. 
The Control-M admins want to create a script that the sysadmins can run to do 
this task, so they don’t have to be actively involved during system maintenance 
on weekends. 
The System Admin group has requested that a Shell script and Windows PowerShell
script are created so that both their Linux and Windows teams will have a script 
they can work with.

## Prerequisites

A Control-M userid has been created named “sysadmin” with the following attributes:
* Assigned Roles: BrowseGroup
* Privileges > Control-M Configuration Manager: Full
* Privileges > Configuration: Update

## Implementation
The scripts will support two actions:

### Stop
The “stop” action will disable the Agent so jobs are no longer scheduled on 
the host. It then checks for a maximum of 5 minutes if jobs are still running 
on the host.  If none are found, a message is printed saying that jobs are no 
longer running on the host and maintenance can continue. If after 5 minutes 
jobs are still found to be running, a message is printed stating to contact 
the Control-M administrators to check on those jobs and take action.

![Script flow](./images/stop-jobs-1.png)

### Start
The “start” action will enable the Agent so jobs can resume scheduling on 
the host.


The [scripts](./scripts) directory contains the final code, and an explanation 
on how they work.
