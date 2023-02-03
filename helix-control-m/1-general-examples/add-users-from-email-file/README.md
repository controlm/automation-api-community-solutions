# Add Users From Email File

Script that will read an ascii text file with email addresses (one per line), and add a new user
to a BMC Helix Control-M tenant for each email address (The user will automatically 
receive a welcome email with temporary password).

## Running

Edit the `add-users-from-email-file.py` script, to change the ctmaapi_url variable to point to your tenant.

```
./add-users-from-email-file.py --tokenfile apikey.txt --mailfile email-addresses.txt
```

Where:
* apikey.txt is a text file containing the API Token. This Token must have Administrator privileges for it to be able to add users.
* email-addresses.txt is a text file containing email addresses of users to be added, one per line.

