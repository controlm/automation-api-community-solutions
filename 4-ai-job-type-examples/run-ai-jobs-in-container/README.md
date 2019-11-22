# Running Control-M Application Integrator jobs in a Container

The example demonstrates how a Linux Container can be created that will run a Control-M/Agent and Control-M Application Pack to run Control-M Application Integrator jobs from within the container.

## Prerequisites

* Control-M/Enterprise Manager 9.0.18.000 or higher
* Control-M Automation API 9.0.00.500 or higher
* Control-M User with following Privileges
  * Privileges > Control-M Configuration Manager: Full
  * Privileges > Configuration: Full (allows agents to be added and deleted)
* Docker installation

## Implementation

This example uses a shell script script as the entry point. This script as 3 main sections:

1. Provision a new Control-M/Agent (Including Application Pack)
2. Deploy a list of user specific Application Integrator job types to the Control-M/Agent
3. Deploy a Connection Profile or Conection Profiles using the Automation API json format (Optionally using a Deploy Descriptor)

### Provisioning

To provision a Control-M/Agent that includes Application Pack, the following must be done on the Control-M/Enterprise Manager:

  1. Download the Control-M/Agent installation file (for the desired version) into the AUTO_DEPLOY directory  
  2. Copy the the Application Pack deployment file (DR1CM...) for the desired version from the CM_DEPLOY directory into the AUTO_DEPLOY directory  
  3. Create a provision image descriptor file (in emweb/automation-api/downloads/descritors/) that references the above files by name. See the below reference example:

  ```json
  {
      "OS": "Linux-x86_64",
      "Installers":
      [
        "DRKAI.9.0.19.100_Linux-x86_64.tar.Z",
        "DR1CM.9.0.19.100_Linux-x86_64.tar.Z"
      ]
  }
  ```

With the Control-M/Enterprise Manager setup complete, the part of the script that provisions the Control-M/Agent, using the [ctm provision agent::install](https://docs.bmc.com/docs/automation-api/9019100monthly/provision-service-872868763.html#Provisionservice-provUpgrade_installprovisionupgrade::install) command, is able to succeed.

Belew is a snipet of the section of [entrypoint.sh](./entrypoint.sh#L318-327) that performs this step:

```bash
ctm provision agent::install $IMAGE $CTM_SERVER $ALIAS $CTM_AGENT_PORT -f /tmp/provision_config.json
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Failed to connect & register image with control-m environment ($RC)"
    removeAgentFromServer
    exit 5
else
    echo "Successfully connected & registered image with control-m environment"
    . ~/.bash_profile
fi
```

### Application Integrator Job Type Deployment

Once the Agent is provisioned, the script then looks at the value specified after the -t or --types argument. This value should be a single Application Integrator Job Type ID, or a comma separated list of Application Integrator Job Type IDs. This value is split into an array, and the following logic is performed:

* For each jobtype in the array
  * Check if the job type is able to be deployed, using the [ctm deploy ai:jobtypes::get](https://docs.bmc.com/docs/automation-api/9019100monthly/deploy-service-872868746.html#Deployservice-AI_getdeployai:jobtypes::get) command
    * If a job type is not ready to be deployed, the `fail` variable is set, which causes the function to exit before attempting to deploy the job types. (As it would have failed anyways)
* For each jobtype in the array
  * Deploy the job type to the newly provisioned Control-M/Agent, using the [ctm deploy ai:jobtype](https://docs.bmc.com/docs/automation-api/9019100monthly/deploy-service-872868746.html#Deployservice-AI_deploydeployai:jobtype) command.
  * Check the return code
* If successful, script contiues to Connection Profile Deployment section
* If the deployment failed and the `--max-retries` flag was not set, the script will loop until the deployment succeeds
* If the deployment failed and the `--max-retries` flag was set, the script will retry the deployment until reaching the maximum number of retries.

### Connection Profile Deployment

Deploying Connection Profiles to the newly provisioned Control-M/Agent follows similar logic to the previous AI Job Type Deployment section. The main differences are:

1. If the `--deploy-descriptor` flag is provided, any occurances of `$ALIAS` and `$CTM_SERVER` in the Deploy Descriptor json file are converted (by envsubst) to the values provided to the `--alias` and `--server` flags respectively
2. The connection profile is deployed using the [ctm deploy](https://docs.bmc.com/docs/automation-api/9019100monthly/deploy-service-872868746.html#Deployservice-deploy) command

## Usage

### Building the container

To build the container, using Docker, do the following:

1. Navigate to the directory containing the Dockerfile and entrypoint.sh script
2. Run the following command, where ctmag:9.0.19.100 is the desired container image tag: `docker build -t ctmag:v0.0.0 .`

### Running in a container

To run the container built in the previous section run the following command, where 7006 is the desired server to agent port, ctm-dc is the Control-M/Server Data Center name, the file `authz.txt` in the current directory contains the Control-M Password:

```bash
docker run -it -v $(pwd):/tmp/test -p 7006:7006 ctmag:v0.0.0 -s clm-aus-t5eocu -e https://clm-aus-trvt6e.bmc.com:8443/automation-api -p 7006 -u emuser -pf /tmp/test/authz.txt -a $HOSTNAME -i AppPack9191.Linux
```

To enable the option Application Integrator job type deployment and connection profile deployment the `-t` and `-cp` options are added:

```bash
docker run -it -v $(pwd):/tmp/test -p 7006:7006 ctmag:v0.0.0 -s clm-aus-t5eocu -e https://clm-aus-trvt6e.bmc.com:8443/automation-api -p 7006 -u emuser -pf /tmp/test/authz.txt -a $HOSTNAME -i AppPack9191.Linux -t ECHOAPI -cp /tmp/test/conn-pofiles.json
```
