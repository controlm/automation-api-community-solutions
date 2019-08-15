# List Control-M/Server Hostgroups and associated Control-M/Agents
## Requirement
A Control-M System Administrator needs to be able to quickly see a high level overview of the environment status at a glance, allowing easy identification of any hostgroups that may be experiencing issues. To accomplish this a script is written that shows all of the defined hostgroups, as well as what Control-M/Agents are associated with those hostgroups and the related status of said Control-M/Agents.

# Prerequisites
A Control-M userid has been created named “sysadmin” with the following (minimum) attributes:

* Control-M/Enterprise Manager 9.0.19 or higher
* Control-M Automation API 9.0.18.300 or higher
* Assigned Roles: BrowseGroup
* Privileges > Control-M Configuration Manager: Full
* Privileges > Configuration: Browse
* python3.7+

## Implementation
This python script is broken in to 3 layers:
1.  Get the list of hostgroups - [/automation-api/config/server/$ctm/hostgroups](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-configserver:hostgroups::get)
2.  For each hostgroup, get the list of associated agent - [/automation-api/config/server/$ctm/hostgroup/$hostgroup/agents](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-configserver:hostgroup:agents::get)
3.  Check the status of each agent from step 2 - [/automation-api/config/server/$ctm/agent/$agent/ping](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Config+service#Configservice-configserver:agent::ping)

Finally the information is displayed to the user running the script.

### Usage
The interface of the hostgroup_list.py script is modeled after the official Automation API `ctm` CLI.

  - `python hostgroup_list.py env add <name> <endpoint> <username> <password>`
  - `python hostgroup_list.py env set <name>`
  - `python hostgroup_list.py env rm <name>`
  - `python hostgroup_list.py env show`

 After adding an environment and setting it as the default environment, list the hostgroup status by running:   
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;```python hostgroup_list.py list <ctm>```

Below is example output for an environment that has 2 hostgroups (DB and k8s-ctm) where each hostgroup has 1 offline node.
 ```
 Hostgroup: DB
+-------------+----------+
| host        | status   |
+=============+==========+
| db-node-01  | Online   |
+-------------+----------+
| db-node-02  | Offline  |
+-------------+----------+
| db-node-03  | Online   |
+-------------+----------+
Hostgroup: k8s-ctm
+--------------------------+----------+
| host                     | status   |
+==========================+==========+
| k8s-ctm-7644865d97-2v8d5 | Online   |
+--------------------------+----------+
| k8s-ctm-7644865d97-2bwn6 | Online   |
+--------------------------+----------+
| k8s-ctm-7644865d97-29wjw | Online   |
+--------------------------+----------+
| k8s-ctm-7644865d97-x5x2p | Offline  |
+--------------------------+----------+
| k8s-ctm-7644865d97-2kzkp | Online   |
+--------------------------+----------+
```

### Installation
1. Download or fork this project
2. In the create a [virtual environment](https://docs.python.org/3/tutorial/venv.html) using python 3.7:  
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;```python3 -m venv hostgroup-venv```
3. Active the virtual environment:  
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;```. houstgroup-venv/bin/activate```
4. Install required packages using pip:  
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;```pip install -r requirements.txt```
5. The hostgroup-list.py script can now be run while in this virtual environment

### Documentation
This example is documented [here](./code-doc.md)
