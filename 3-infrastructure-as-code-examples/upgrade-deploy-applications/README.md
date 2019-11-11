# Using Automation API to upgrade Control-M/Agent, install fix packs, and deploy applications

This example demonstrates using the Automation API [Provision Service](https://docs.bmc.com/docs/automation-api/9019100monthly/provision-service-872868763.html#Provisionservice-provisionUpgradeUpgradinganexistingControl-M/Agentanddeployingapplicationplug-ins) to upgrade
Control-M/Agent, install fix packs, deploy Managed File Transfer, and deploy application pack on CentOS 7.6.  The same process is possible for other Unix and  Windows environments with similar configration. Currently, MFT 9.0.19 can only deployed to Control-M/Agent 9.0.18 so this example will show upgrading Control-M/Agent to 9.0.18 as a first step.  This example shows only 1 possible upgrade path.

Pre-Requisites:
* Control-M/Enterprise Manager 9.0.19 or higher with installation packages
* Control-M Managed File Transfer 9.0.19
* Control-M Automation API 9.0.18 or higher
* Control-M/Agent 9.0.00 or higher
* A Control-M user id with the following minimal privileges:
    * Privileges > Control-M Configuration Manager: Full
    * Privileges > Configuration: Update

In this example, we will upgrade the following base configuration on agent host *testdev-1*:
* Control-M/Agent 9.0.00 on CentOS 7.6
* Control-M Advanced File Transfer 8.2.00

The target will have the following configuration:
* Control-M/Agent 9.0.18 on CentOS 7.6
* Control-M Managed File Transfer 9.0.19
* Application Pack 9.0.19

### Table of Contents
1. [Installation](#1-installation-packages)
2. [Get list of packages](#2-get-list-of-available-deployments)
3. [Get list of eligible upgrades](#3-get-list-of-agents-and-eligible-upgrades)
4. [Upgrade Control-M/Agent](#4-apply-an-upgrade)
5. [Upgrade AFT to MFT](#5-upgrade-aft)
6. [Deploy Application Pack](#6-deploy-application-pack)
7. [Verify Installation](#7-verify-installation)

### 1. Installation Packages

Before Agent upgrades and fix packs can be deployed the agent base installations and fix packs must be copied to the Enterprise Manager as described in the [Control-M Deployment](http://documents.bmc.com/supportu/9.0.19/help/Main_help/en-US/index.htm#50760.htm).
The following describes how to obtain packages and where to copy the packages.<br>
http://documents.bmc.com/supportu/9.0.19/help/Main_help/en-US/index.htm#AutoDeployCopyingPackages.htm
<br><br>
MFT and Application Pack packages are stored in $EM_HOME/CM_DEPLOY and are managed by the Control-M installation setup process.

### 2. Get list of available deployments
With [provision upgrades:versions::get](https://docs.bmc.com/docs/automation-api/9191/provision-service-869536967.html#Provisionservice-versions_getprovisionupgrades:versions::get) get a list of available upgrades and application packages available for Control-M/Agent deployments.

```
ctm provision upgrades:versions::get
[
  {
    "type": "Agent",
    "version": "9.0.18.100"
  },
  {
    "type": "Agent",
    "version": "9.0.18.200"
  },
  {
    "type": "Agent",
    "version": "9.0.00.400"
  },
  {
    "type": "Agent",
    "version": "9.0.19.000"
  },
  {
    "type": "MFT",
    "version": "9.0.19.000"
  },
  {
    "type": "AppPack",
    "version": "9.0.19.000"
  }
]
```
<br>
The list above shows packages for Control-M Agent fix pack 9.0.00.400, Control-M/Agent 9.0.18.100, Control-M/Agent 9.0.18.200, Control-M/Agent 9.0.19, Control-M Managed File Transfer 9.0.19, and Application Pack 9.0.19.

### 3. Get list of agents and eligible upgrades 

To get a list of agents and their eligible upgrades run [provision upgrades:agents::get](https://docs.bmc.com/docs/automation-api/9019100monthly/provision-service-872868763.html#Provisionservice-agents_getprovisionupgrades:agents::get).
```
 ctm provision upgrades:agents::get
[
  {
    "agent": "devtest-1",
    "ctm": "wla919",
    "type": "Agent",
    "platform": "Linux-x86_64",
    "fromVersion": "9.0.00",
    "toVersion": "9.0.18.100"
  },
  {
    "agent": "devtest-1",
    "ctm": "wla919",
    "type": "Agent",
    "platform": "Linux-x86_64",
    "fromVersion": "9.0.00",
    "toVersion": "9.0.18.200"
  },
  {
    "agent": "devtest-1",
    "ctm": "wla919",
    "type": "Agent",
    "platform": "Linux-x86_64",
    "fromVersion": "9.0.00",
    "toVersion": "9.0.00.400"
  },
  {
    "agent": "devtest-1",
    "ctm": "wla919",
    "type": "Agent",
    "platform": "Linux-x86_64",
    "fromVersion": "9.0.00",
    "toVersion": "9.0.19.000"
  },
  {
    "agent": "wla919",
    "ctm": "wla919",
    "type": "MFT",
    "platform": "Linux-x86_64",
    "fromVersion": "",
    "toVersion": "9.0.19.000"
  }
]
```
The above examples shows agent *devtest-1* has serveral possible upgrades.

### 4. Apply an upgrade 

Execute [provision upgrade::install](https://docs.bmc.com/docs/automation-api/9191/provision-service-869536967.html#Provisionservice-provUpgrade_installprovisionupgrade::install) to apply an update and check the status with [provision upgrades::get](https://docs.bmc.com/docs/automation-api/9191/provision-service-869536967.html#Provisionservice-provUpgrade_getStatusprovisionupgrade::get).<br>
Below shows an example output of upgrading Control-M/Agent 9.0.00 directly to 9.0.18.
```
ctm provision upgrade::install wla919 devtest-1 Agent 9.0.18.200 "Upgrade 9.0.00 agent to 9.0.18.200"
{
  "upgradeId": "wla919:6"
}

ctm provision upgrade::get "wla919:6"
{
  "upgradeId": "wla919:6",
  "ctm": "wla919",
  "agent": "devtest-1",
  "fromVersion": "9.0.00",
  "toVersion": "9.0.18.200",
  "activity": "Install",
  "status": "Running",
  "message": "Server to Agent: 55% of 427 MB transferred (bandwidth used 968 KB/sec)",
  "creationTime": "2019-10-03T07:43:12Z",
  "transferStartTime": "2019-10-03T07:43:18Z",
  "transferEndTime": "",
  "installStartTime": "",
  "installEndTime": "",
  "activityName": "Upgrade 9.0.00 agent to 9.0.18.200",
  "installUser": "ctmagent",
  "notifyAddress": "",
  "description": "",
  "package": "DRKAI.9.0.18.200_Linux-x86_64.tar.Z"
}

ctm provision upgrade::get "wla919:6"
{
  "upgradeId": "wla919:6",
  "ctm": "wla919",
  "agent": "devtest-1",
  "fromVersion": "9.0.00",
  "toVersion": "9.0.18.200",
  "activity": "Install",
  "status": "Running",
  "message": "Activating Control-M/Agent upgrade",
  "creationTime": "2019-10-03T07:43:12Z",
  "transferStartTime": "2019-10-03T07:43:18Z",
  "transferEndTime": "2019-10-03T07:53:28Z",
  "installStartTime": "2019-10-03T07:53:28Z",
  "installEndTime": "",
  "activityName": "Upgrade 9.0.00 agent to 9.0.18.200",
  "installUser": "ctmagent",
  "notifyAddress": "",
  "description": "",
  "package": "DRKAI.9.0.18.200_Linux-x86_64.tar.Z"
}

ctm provision upgrade::get "wla919:6"
{
  "upgradeId": "wla919:6",
  "ctm": "wla919",
  "agent": "devtest-1",
  "fromVersion": "9.0.00",
  "toVersion": "9.0.18.200",
  "activity": "Install",
  "status": "Completed",
  "message": "Control-M/Agent Upgrade Completed Successfully",
  "creationTime": "2019-10-03T07:43:12Z",
  "transferStartTime": "2019-10-03T07:43:18Z",
  "transferEndTime": "2019-10-03T07:53:28Z",
  "installStartTime": "2019-10-03T07:53:28Z",
  "installEndTime": "2019-10-03T07:54:20Z",
  "activityName": "Upgrade 9.0.00 agent to 9.0.18.200",
  "installUser": "ctmagent",
  "notifyAddress": "",
  "description": "",
  "package": "DRKAI.9.0.18.200_Linux-x86_64.tar.Z"
}
```

### 5. Upgrade AFT

Once the Control-M/Agent has been upgraded we can upgrade AFT 8.2 to MFT 9.0.19 with one command.

```
ctm provision upgrade::install wla919 devtest-1 MFT 9.0.19.000 "Upgrade AFT 8.2.00 to MFT 9.0.19.000"
{
  "upgradeId": "wla919:7"
}


ctm provision upgrade::get "wla919:7"
{
  "upgradeId": "wla919:7",
  "ctm": "wla919",
  "agent": "devtest-1",
  "fromVersion": "",
  "toVersion": "9.0.19.000",
  "activity": "Install",
  "status": "Running",
  "message": "Server to Agent: 13% of 235 MB transferred (bandwidth used 957 KB/sec)",
  "creationTime": "2019-10-03T07:57:32Z",
  "transferStartTime": "2019-10-03T07:57:36Z",
  "transferEndTime": "",
  "installStartTime": "",
  "installEndTime": "",
  "activityName": "Upgrade AFT 8.2.00 to MFT 9.0.19.000",
  "installUser": "ctmagent",
  "notifyAddress": "",
  "description": "",
  "package": "DRAFT.9.0.19.000_Linux-x86_64.tar.Z"
}

ctm provision upgrade::get "wla919:7"
{
  "upgradeId": "wla919:7",
  "ctm": "wla919",
  "agent": "devtest-1",
  "fromVersion": "",
  "toVersion": "9.0.19.000",
  "activity": "Install",
  "status": "Completed",
  "message": "Control-M for Managed File Transfer Install Completed Successfully; Agent availability was verified",
  "creationTime": "2019-10-03T07:57:32Z",
  "transferStartTime": "2019-10-03T07:57:36Z",
  "transferEndTime": "2019-10-03T08:03:10Z",
  "installStartTime": "2019-10-03T08:03:10Z",
  "installEndTime": "2019-10-03T08:03:34Z",
  "activityName": "Upgrade AFT 8.2.00 to MFT 9.0.19.000",
  "installUser": "ctmagent",
  "notifyAddress": "",
  "description": "",
  "package": "DRAFT.9.0.19.000_Linux-x86_64.tar.Z"
}
```

### 6. Deploy Application Pack
With application pack, new Control-M module such as Databases,  Hadwoop, AWS, SAP, Web Services can be deployed to the Control-M/Agent simply.
```
ctm provision upgrade::install wla919 devtest-1 AppPack 9.0.19.000 "Deploy Application Pack 9.0.19.000"
{
  "upgradeId": "wla919:8"
}

ctm provision upgrade::get "wla919:8"
{
  "upgradeId": "wla919:8",
  "ctm": "wla919",
  "agent": "devtest-1",
  "fromVersion": "",
  "toVersion": "9.0.19.000",
  "activity": "Install",
  "status": "Running",
  "message": "Server to Agent: 11% of 199 MB transferred (bandwidth used 943 KB/sec)",
  "creationTime": "2019-10-03T15:35:59Z",
  "transferStartTime": "2019-10-03T15:36:33Z",
  "transferEndTime": "",
  "installStartTime": "",
  "installEndTime": "",
  "activityName": "Deploy Application Pack 9.0.19.000",
  "installUser": "ctmagent",
  "notifyAddress": "",
  "description": "",
  "package": "DR1CM.9.0.19.000_Linux-x86_64.tar.Z"
}

ctm provision upgrade::get "wla919:8"
{
  "upgradeId": "wla919:8",
  "ctm": "wla919",
  "agent": "devtest-1",
  "fromVersion": "",
  "toVersion": "9.0.19.000",
  "activity": "Install",
  "status": "Completed",
  "message": "Control-M Application Pack Install Completed Successfully; Agent availability was verified",
  "creationTime": "2019-10-03T15:35:59Z",
  "transferStartTime": "2019-10-03T15:36:33Z",
  "transferEndTime": "2019-10-03T15:41:17Z",
  "installStartTime": "2019-10-03T15:41:17Z",
  "installEndTime": "2019-10-03T15:41:38Z",
  "activityName": "Deploy Application Pack 9.0.19.000",
  "installUser": "ctmagent",
  "notifyAddress": "",
  "description": "",
  "package": "DR1CM.9.0.19.000_Linux-x86_64.tar.Z"
}
```

### 7. Verify Installation

To confirm the upgrades and deployments were successfull the *installed-versions.txt* in the Control-M/Agent's home installation directory can be reviewed.
```
cat installed-versions.txt

PIM                      PLATFORM       PACKAGE-DATE   INSTALL-DATE   VERSION        INSTALL-TYPE   COMMENTS
___________________________________________________________________________________________________________________
DRKAI.9.0.00             Linux-x86_64   Jun-09-2015    Oct-03-2019    9.0.00.000     INSTALLATION   Agent 64-bit
DRAFT.8.2.00             Linux-x86_64   Jan-16-2017    Oct-03-2019    8.2.00.000     INSTALLATION   Control-M Advanced File Transfer
PAKAI.9.0.18.200         Linux-x86_64   Sep-06-2018    Oct-03-2019    9.0.18.200     UPGRADE        Control-M/Agent 9.0.18.200
PAAFT.9.0.19.000         Linux-x86_64   Jan-31-2019    Oct-03-2019    9.0.19.000     UPGRADE        Control-M Managed File Transfer Agent Plugin 9.0.19.000
DR1CM.9.0.19.000         Linux-x86_64   Dec-26-2018    Oct-03-2019    9.0.19.000     INSTALLATION   Control-M Application Pack
DRBKP.9.0.19.000         Linux-x86_64   Dec-26-2018    Oct-03-2019    9.0.19.000     INSTALLATION   Control-M for Backup
DRMQL.9.0.19.000         Linux-x86_64   Dec-26-2018    Oct-03-2019    9.0.19.000     INSTALLATION   Control-M for Databases
DRAIT.9.0.19.000         Linux-x86_64   Dec-26-2018    Oct-03-2019    9.0.19.000     INSTALLATION   Control-M Application Integrator
DRCBD.9.0.19.000         Linux-x86_64   Dec-26-2018    Oct-03-2019    9.0.19.000     INSTALLATION   Control-M for Hadoop
DRAMZ.9.0.19.000         Linux-x86_64   Dec-26-2018    Oct-03-2019    9.0.19.000     INSTALLATION   Control-M for AWS
DRAZR.9.0.19.000         Linux-x86_64   Dec-26-2018    Oct-03-2019    9.0.19.000     INSTALLATION   Control-M for Azure
```