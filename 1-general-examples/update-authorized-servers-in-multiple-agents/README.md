# Update Authorized Servers in multiple Agents

## Requirement

A new DR environment has been set up, which includes the Control-M products.
As the production Control-M/Agents have a parameter "Authorized Control-M/Server
Hosts" which lists the Control-M/Server hosts allowed to connect to the Agent,
the new DR server needs to be added to that list so that it will be able to
connect to those Agents immediately, should that become necessary.

## Prerequisites

* Control-M Automation API 9.0.18 or higher
* Python 3.6 or higher (lower versions may work but have not been tested)

## Script

A Python script was developed to use Control-M Automation API requests that
retrieve a list of all Agents connected to a given Control-M/Server, and loop
through all available Agents to update their "Authorized Control-M/Server 
Hosts".
The option to add or delete a host from the list was creatd, so that old 
servers can also be removed from the list.

The complete [script](./scripts/).
