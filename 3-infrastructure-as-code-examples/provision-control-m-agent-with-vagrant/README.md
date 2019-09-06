# Provision Control-M Agent with Vagrant

## Requirement

The development team uses Vagrant to provision various virtual machines to develop and test their programs.  Vagrant allows them to quickly and easily provision 
virtual machines as needed for various platforms and configuration.  As part of the testing they would like to test their programs while running under a Control-M/Agent
environment but they are not familar with Control-M.  As a solution the Control-M Automation API is able to provision a Control-M Agent and register it with a 
Control-M Server automatically.  It can also unregister,undeploy, and uninstall the Control-M Agent.  This allows developers to test against Control-M Agent without 
having to involve the Control-M administrator.

## Prerequisites
* Vagrant 2.2.4 or higher
* VirtualBox 6.0 or higher
* Control-M/Enterprise Manager 9.0.18.200 or higher
* Automation API 9.0.18.200 or higher
* A Control-M user id with the following minimal privileges:
    * Privileges > Control-M Configuration Manager: Full
    * Privileges > Configuration: Update
    * Privileges > Configuration: Full (allows agent to be deleted)
    * Additional Folder and Run As User permissions may be needed for job deployment and execution.

## Implementation

![Script flow](./images/provision-agent-vagrant-1.png)

## Video

The following video demonstrates the above steps.

[![Video Demo Link](./images/provision-agent-vagrant-2.png "Video Demo on YouTube")](https://youtu.be/bOy0ZvhIOr8)

Click the above image to watch the video on YouTube.

## Table of Contents
1. [Vagrantfile & Scripts](./scripts)


