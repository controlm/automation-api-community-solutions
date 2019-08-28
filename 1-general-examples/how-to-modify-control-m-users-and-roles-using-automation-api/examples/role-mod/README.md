# Example Case:
A business unit changed the naming scheme of their jobs so the AllowedJobs filters for that group needs to be modified.

TeamB is splitting into two separate teams as the scope of the project has grown and diverged into two logical parts making the split reasonable.

TeamB currently uses the prefix ```B*``` on all of their Folders and Applications, once split the new teams TeamBravo and TeamBeta will use the prefixes ```Bravo-*``` and ```Beta-*``` on their respective folders and applications.

If the exact name of the role that needs to be changed ins't known, the [config authorization:roles::get](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-roles_getconfigauthorization:roles::get) Automation API service can be used to find the role using search criteria.
```
$ ctm config authorization:roles::get -s "role=Team?&description=B*"
[
  {
    "name": "TeamB",
    "description": "B-Team"
  }
]
```

Now that the role name is known, the role definition can be retrieved in json format using the [config authorization:role::get](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-role_getconfigauthorization:role::get) Automation API service.
 - It is useful to redirect the response to a file so that it can be later modified:

```
$ ctm config authorization:role::get TeamB > TeamB.json
```

See [TeamB.json](./TeamB.json) in the current directory for an example of what the response looks like.


With current TeamB role definition saved as a json file, it can be modified. It is a good idea however to keep the original and only modify copies under new names:
```
$ cp TeamB.json TeamBravo.json
$ cp TeamB.json TeamBeta.json
```

For both the TeamBravo.json and TeamBeta.json files, the following sections need to be modified:
```
  "Name": "TeamB",
  "Description": "B-Team",
```

```
  "AllowedJobs": {
    "Included": [
      [
        [
          "Folder",
          "like",
          "B*"
        ],
        [
          "FileName",
          "like",
          "*"
        ]
      ],
      [
        [
          "Application",
          "like",
          "B*"
        ],
        [
          "FileName",
          "like",
          "*"
        ]
      ]
    ]
  },
```

```
  "Folders": [
    {
      "Privilege": "Browse",
      "ControlmServer": "*",
      "Library": "*",
      "Folder": "B*",
      "Jobs": {
        "Privilege": "Browse",
        "Application": "B*",
        "SubApplication": "*"
      }
    }
  ],
```

**Note**: The need to modify specific these sections, and only these sections, is specific to this example, in a real-world environment the sections that need to be modified will depend on the individual business needs and use case.

This can be done manually in a text editor, but since we know the patterns that need to be changed we'll use the below sed command for expedience:
```
$ sed -i 's/"TeamB"/"TeamBravo"/;s/"B-Team"/"Bravo-Team"/;s/"B\*"/"Bravo-\*"/g' TeamBravo.json
$ sed -i 's/"TeamB"/"TeamBeta"/;s/"B-Team"/"Beta-Team"/;s/"B\*"/"Beta-\*"/g' TeamBeta.json
```

See [TeamBravo.json](./TeamBravo.json) and [TeamBeta.json](./TeamBeta.json) in the current directory to see the files after modification.

The modified files can now be used to create new roles using the [config authorization:role::add](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-role_addconfigauthorization:role::add) Automation API service:
```
$ ctm config authorization:role::add TeamBravo.json
{
  "message": "Role was created successfully."
}

$ ctm config authorization:role::add TeamBeta.json
{
  "message": "Role was created successfully."
}
```

When to begin the switch, change the role association for the appropriate users by using the [config authorization:user:role::add](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-user_addRoleconfigauthorization:user:role::add) and [config authorization:user:role::delete](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-user_removeRoleconfigauthorization:user:role::delete) Automation API services.
```
$ ctm config authorization:user:role::add BetaUser1 TeamBeta
{
  "message": "Role 'TeamBeta' was successfully added to user 'BetaUser1'."
}

$ ctm config authorization:user:role::delete BetaUser1 TeamB
{
  "message": "Role 'TeamB' was successfully removed from user 'BetaUser1'."
}
...
$ ctm config authorization:user:role::add BetaUserN TeamBeta
{
  "message": "Role 'TeamBeta' was successfully added to user 'BetaUserN'."
}

$ ctm config authorization:user:role::delete BetaUserN TeamB
{
  "message": "Role 'TeamB' was successfully removed from user 'BetaUserN'."
}

$ ctm config authorization:user:role::add BravoUser1 TeamBravo
{
  "message": "Role 'TeamBravo' was successfully added to user 'BravoUser1'."
}

$ ctm config authorization:user:role::delete BravoUser1 TeamB
{
  "message": "Role 'TeamB' was successfully removed from user 'BravoUser1'."
}
...
$ ctm config authorization:user:role::add BravoUserN TeamBravo
{
  "message": "Role 'TeamBravo' was successfully added to user 'BravoUserN'."
}

$ ctm config authorization:user:role::delete BravoUserN TeamB
{
  "message": "Role 'TeamB' was successfully removed from user 'BravoUserN'."
}
```

Finally, once all the necessary changes have been made and tested, the old TeamB role and be removed using the config [authorization:role::delete](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-role_deleteconfigauthorization:role::delete) Automation API service. This allows the role definition to be retained as the json definition file (In Version Control System, ie Git, File share, or object storage like S3) which provides a convent option to add the group back if an issue is found at a later time and the change needs to be rolled back or the changes need to be reviewed for audit purposes.