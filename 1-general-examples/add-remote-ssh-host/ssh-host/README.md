# Add remote ssh host

This example demonstrates how to add a remote host named *devopstest* to Control-M/Server using SSH.  It uses the [Automation API commandline](https://docs.bmc.com/docs/automation-api/9191/installation-857507310.html).  However, access to the Control-M Automation REST API is also possible using *curl* or other REST API capable tools.

## Adding Remote Host
Using [config server:remotehost::add](https://docs.bmc.com/docs/automation-api/9191/config-service-869536965.html#Configservice-configserver:remotehost::add) a host can be added.

#### Basic Example (using defaults)
The basic format can be used for most typical configurations.
```
ctm config server:remotehost::add wla919 devopstest
{
  "message": "Successfully add remote host devopstest to wla919"
}
```

#### Example (using configuration file)
Using a configration file allows additional features such specifying encryption algorithm and specifying the host that will manage the remote host.
```
cat devopstest.json
{
    "remotehost" : "devopstest",
    "port" : 22,
    "agents": [
        "wla919"
    ],
    "encryptAlgorithm": "BLOWFISH",
    "compression": "false",
    "authorize": "true"
}

ctm config server:remotehost::add wla919 devopstest -f devopstest.json
{
  "message": "Successfully add remote host devopstest to wla919"
}
```


## Adding remote host to remote host authorization list
If remote host was not authorized when it was added it can be done with [config server:remotehost::authorize](https://docs.bmc.com/docs/automation-api/9191/config-service-869536965.html#Configservice-configserver:remotehost::authorize).  This adds the machine to the SSH remote host authorization list.
```
ctm config server:remotehost::authorize wla919 devopstest
{
  "message": "Remote host devopstest was successfully authorized"
}
```

## Adding Run As User
Before a Control-M job can successfuly run against a remote host a run as user must be set up.  The run as user allows the hosting Control-M/Agent to login to the remote host to run jobs via a SSH connection.
The following error will appear in the job log if a run as user is not defined.  
```
Error: Owner: devops is not defined for the remote host: devopstest. Use 'Owners Authentication Settings' or 'ctmsetown' to define it.
```

If using user/password authentication for SSH, [ctm config server:runasuser::add](https://docs.bmc.com/docs/automation-api/9191/config-service-869536965.html#Configservice-runasuser_addconfigserver:runasuser::add) can be executed with the user and password to create the run as user.
```
ctm config server:runasuser::add wla919 devopstest devops devopspassword
{
  "message": "user devops:devopstest created successfully"
}

```
Alternatively, SSH keys can be used instead of using user/password.  In order to use SSH keys the Control-M administartor must setup as described in the [Agentless SSH key management](
http://documents.bmc.com/supportu/9.0.19/help/Main_help/en-US/index.htm#SSHKeyGeneration.htm) documentation.
<br><br>
When using SSH an optional configuration file is required.
```
cat devops_sshkey.json
{
  "key": {
    "keyname": "devops",
    "passphrase": "devopspassword"
  }
}

ctm config server:runasuser::add wla919 devopstest devops -f devops_sshkey.json
{
  "message": "user devops:devopstest created successfully"
}
```

## Testing connection
To test if the runas user and ssh host settings are correct the [config server:runasuser::test](https://docs.bmc.com/docs/automation-api/9191/config-service-869536965.html#Configservice-runasuser_testconfigserver:runasuser::test) can be used.
```
ctm config server:runasuser::test wla919 devopstest devops
{
  "message": "Run-as user 'devops:devopstest' credentials are valid"
}
```

## Removing runas user and remote host from Control-M Server
Once the runas user and remote are no longer deleted they can be removed with [config server:remotehost::delete](https://docs.bmc.com/docs/automation-api/9191/config-service-869536965.html#Configservice-configserver:remotehost::delete)
and [config server:runasuser::delete](https://docs.bmc.com/docs/automation-api/9191/config-service-869536965.html#Configservice-configserver:runasuser::delete).
```
ctm config server:runasuser::delete wla919 devopstest devops
{
  "message": "Run-as user 'devops:devopstest' was deleted"
}

ctm config server:remotehost::delete wla919 devopstest
{
  "message": "Successfully deleted remote host devopstest from wla919"
}
```

## Table of Contents
* [Main README](../README.md)
