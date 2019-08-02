# Vagrant files & scripts

The Vagrant files and scripts are targeted for publicly available Vagrant boxes using Centos 7 and Virtualbox on Windows.  It uses root to install basic requirements
and the standard *vagrant* user to perform non-root actions.  The files ands scripts can be used for other environments but require additional customization.

This directory contains 1 Vagrantfile, 4 scripts, and 1 sample job:
* [Vagrantfile](./Vagrantfile)
* [install_root.sh](./install_root.sh)
* [install_agent.sh](./install_agent.sh)
* [register_agent.sh](./register_agent.sh)
* [unregister_agent.sh](./unregister_agent.sh)
* [Sample Job (VagrantTestJob.json)](./VagrantTestJob.json)


## How to use
* Copy all scripts and files to new Vagrant project or virtual machine directory.
* Set the Windows environment variables CTMUSER and CTMUSERPASSWORD to the Control-M login and password.  The Vagantfile script will retrieve the user login and password 
during execution to register an environment for Automation API.
```
eg
  set CTMUSER=devops
  set CTMUSERPASSWORD=devopspassword
```
* The following variable assignment is used to pass the Windows host machine by passing the %COMPUTERNAME% environment variable to the virtual machine.
```
CTM_AGENT_HOST=ENV["COMPUTERNAME"]
```
* Edit Vagrantfile and modify remaining environment variables at script entry to match working environment.
```
eg
CTM_HOST="wla919"
CTM_SERVER="wla919"
CTM_AGENT_PORT="8006" 
```
CTM_HOST  - Control-M/Enterprise Manager where the Automation API rest server is running.<br>
CTM_SERVER - Control-M/Server defined under the EM Server specified by *CTM_HOST*.<br>
CTM_AGENT_PORT - port accessible between Control-M/Server and the vagrant host.<br>
<br>
Vagrant machines are typically host only or use NAT for networking.  For this reason, the newly registered agent will have the hostname of the virtual machine's host 
followed by it's listening port to allow it to be accessible by Control-M/Server.  In the Configuration Manager the agent will be listed with the format 
CTM_AGENT_HOST:CTM_AGENT_PORT.  With this configuration multiple agents can be registered to the same vagrant host machine using different ports.



* Edit virtual box selection.  At the time of this writing a "centos/7" box was availabe from Centos but the confguration should work with other similar boxes.
```
config.vm.box = "centos/7"
```


* Start Virtual machine
```
vagrant up
or
vagrant up --provision
```

Once the virtual machine is running, the Control-M/Agent should be installed and registered with the desired Control-M/Server.
 A .ctm_env file is created in the *vagrant* user's home directory to save the environment settings.  It is used by the scripts and can be manually sourced
to make executing Automation API commannds simpler using environment variables.

## Post Provision

### To unregister agent from the Control-M/Server but not uninstall
/vagrant/unregister_agent.sh

### To register agent again with the same Control-M/Server
/vagrant/register_agent.sh

### To uninstall agent from vagrant user account and unregister agent
ctm provision agent::uninstall

### To install agent again using same settings
/vagrant/install_agent.sh

### Run Test Job
1. Copy /vagrant/VagrantTestJob.json to home directory and edit.  Replace [VAGRANT_HOST] with the newly registered agent name.  This should be the value of CTM_AGENT_HOST:CTM_AGENT_PORT.
Other job parameters such as ControlmServer and RunAs may need to be changed also.

2. Build job to validate job definition using deploy service.
```
ctm build VagrantTestJob.json
```
3. Submit job for execution  using run service.
```
ctm run VagrantTestJob.json
```
4. Check job status by using the run status service with the runId from step 3.<br><br>

Example:
```
$ ctm build VagrantTestJob.json
[
  {
    "deploymentFile": "VagrantTestJob.json",
    "successfulFoldersCount": 1,
    "successfulSmartFoldersCount": 0,
    "successfulSubFoldersCount": 0,
    "successfulJobsCount": 1,
    "successfulConnectionProfilesCount": 0,
    "successfulDriversCount": 0,
    "isDeployDescriptorValid": false
  }
]

$ ctm run VagrantTestJob.json
{
  "runId": "7ce824dd-4717-4fc8-ba7f-4a5090c8cb22",
  "statusURI": "https://wla919:8443/automation-api/run/status/7ce824dd-4717-4fc8-ba7f-4a5090c8cb22"
}

$ ctm run status "7ce824dd-4717-4fc8-ba7f-4a5090c8cb22"
{
  "statuses": [
    {
      "jobId": "wla919:0000a",
      "folderId": "wla919:00000",
      "numberOfRuns": 1,
      "name": "vagrant_testjob",
      "folder": "Vagrant",
      "type": "Command",
      "status": "Ended OK",
      "held": false,
      "deleted": false,
      "startTime": "Jul 29, 2019 7:17:33 PM",
      "endTime": "Jul 29, 2019 7:17:33 PM",
      "outputURI": "https://wla919:8443/automation-api/run/job/wla919:0000a/output",
      "logURI": "https://wla919:8443/automation-api/run/job/wla919:0000a/log"
    }
  ],
  "startIndex": 0,
  "itemsPerPage": 25,
  "total": 1
}
```

