# How to modify Control-M Users and Roles using Automation API
## Requirements
The Control-M administrator regularly needs to make adjustments to User and Roles authorizations. To work more efficiently, the modification can be made using Automation API with the user and roles definitions exported and modified as JSON.

## Prerequisites
* Control-M/Enterprise Manager 9.0.19 or higher
* Control-M Automation API 9.0.18.300 or higher
* Control-M Account with the following *minimum* permissions:
  * Authorization - Update
  * Configuration Manager - Full

## Implementation
To modify existing users and groups, the following high level steps are required:  
1. Get the json for the existing user or role:
    * If user: [ctm config authorization:user::get <user>](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-user_getconfigauthorization:user::get)
    * If role: [ctm config authorization:role::get <role>](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-role_getconfigauthorization:role::get)
2. Save the json result from step 1, and make the desired modifications.
3. Update Control-M with the modified json:
    * If user: [ctm config authorization:user::update <user> <userFile>](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-user_updateconfigauthorization:user::update)
    * If role: [ctm config authorization:role::update <role> <roleFile>](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-role_updateconfigauthorization:role::update)

Below are specific examples of modifications that can done:
- A user moved teams so the old team's role needs to be removed and the new team's role needs to be added
    * [User Modification](./examples/user-mod)
- A business unit changed the naming scheme of their jobs so the AllowedJobs filters for that group needs to be modified
    * [Role Modification](./examples/role-mod)

## Demo
Click on the below image to watch a demonstration on YouTube.
[![Video Demo Link](https://img.youtube.com/vi/Dqn849XK94g/0.jpg "Video Demo on YouTube")](https://youtu.be/Dqn849XK94g)
