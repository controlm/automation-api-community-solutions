# Example Case:
A user moved teams so the old team's role needs to be removed and the new team's role needs to be added.

If the exact username for the user that needs to be modified isn't known, the [config authorizations:users::get](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-users_getconfigauthorization:users::get) Automation API service can be used to search for the user with search criteria: 

```
$ ctm config authorization:users::get -s "name=Example*"
[
  {
    "name": "ExampleUser",
    "fullName": "Example User",
    "description": "User to Demo"
  }
]

```

Now that the username is known, the user definition can be retrieved as json with the [config authorizations:user::get](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-user_getconfigauthorization:user::get) Automation API service.
 - It is useful to redirect the response to a file so that it can be later modified:

```
$ ctm config authorization:user::get ExampleUser > before.json
```

This created the file [before.json](./before.json) in this directory.

The relevant section of this file is:
```
  "Roles": [
    "TeamA"
  ],
```

As this user has moved to TeamB, we need to change the above section to:
```
  "Roles": [
    "TeamB"
  ],
```
See [after.json](./after.json)

**Note:** This change can be made manually using a text editor, using Linux/Unix commmand line utilities such as sed (ie: ```sed 's/TeamA/TeamB/' before.json > after.json```), or even the json processed in a more complicated application written in python or another language that can parse the JSON.

With the modified files, the changes are pushed into Control-M using the [config authorization:user::update](https://docs.bmc.com/docs/automation-api/919110/config-service-872868754.html#Configservice-user_updateconfigauthorization:user::update) Automation API service.

   * **NOTE**: If any user authorization settings are removed from the json file the setting will revert to the default value
   
```
$ ctm config authorization:user::update ExampleUser after.json
{
  "message": "User was updated successfully."
}
```