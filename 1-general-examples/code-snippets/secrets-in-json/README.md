# Using Automation API Secrets in JSON definition

This should be done in connection profiles (and any other place where a password or sensitive info is needed in a json definition)

To define a secret:
```shell
$ ctm config secret::add mySuperSecretPassword Password1
```

In the connection profile JSON file replace `Password1` with `{"Secret": "mySuperSecretPassword"}`:
```json
{
"LocalConn" : {
   "Type" : "ConnectionProfile:FileTransfer:Local",
   "TargetAgent" : "AgentHost",
   "TargetCTM" : "workbench",
   "User" : "controlm",
   "Password" : {"Secret": "mySuperSecretPassword"}
    }
}
```

When the connection profile is deployed with the below command, the secret is resolved by the Automation API server
```shell
ctm deploy myMFTConnProfile.json
```