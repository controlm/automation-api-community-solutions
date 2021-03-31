# Copyright © BMC Software, Inc. All rights reserved.

Access and use of the following is governed by the terms and conditions set forth in LICENSE in the project root.

Changes may cause incorrect behavior and will be lost if the code is regenerated.

# Control-M Integration for Azure Logic Apps
This folder contains a sample Application Integrator jobtype for running and monitoring Azure Logic Apps, which is a Microsoft Azure cloud service that helps to integrate apps, data, systems, and services across enterprises or organizations. 

## Prerequisites and installation notes:

This job type has the following prerequisites:

* Control-M Agent with Application Integrator deployed
* PowerShell 7 or higher, installed on Windows and Linux
* Azure PowerShell library installed

### Installation steps:

* Deploy the job type to the agent via the Application Integrator graphical UI or via Automation API. 
* Copy the PowerShell script to the agent machine(s)
* Configure a connection profile containing an Azure Tenant ID, Subscription ID,  Service Principal, Client secret and fully qualified path of the PowerShell script
* Create your first job

### Compatibility:

* Platforms: This job type was tested on both Linux and Windows.
* Control-M: Tested on Control-M 9.0.19.200 and 9.0.20.000
* Connection Profile: Can be either Centralized or Local

## Connection profile

Before any job can be run, a connection profile is required. Below is an example:
```
{
  "<CONNECTION_PROFILE NAME>" : {
    "Type": "ConnectionProfile:ApplicationIntegrator:AI AzureLogicApps",
    "AI-Subscription ID": "fee1b749-2ef4-4205-a1a5-3fdb5b803697",
    "AI-Password": ".iAes520RF__hgzysx4lyGF_2aHWTL-.s5",
    "AI-Application ID": "736885f5-34e9-4d86-a5c9-91b812193116",
    "AI-Tenant ID": "92b796c5-5839-40a6-8dd9-c1fad320c69b",
    "Centralized": true
  }
}
```