# Reusable Python code blocks

## Imports
Standard import that are likely needed for any Python script calling AAPI:
[here](./code_blocks.py#L1-2)
```Python
import requests
import json
```

If you want to disable the insecure request warns that are generated if you pass `verify=false` to requests, add [this line](./code_blocks.py#L3) and [this line](./code_blocks.py#L19)
```Python
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
```

## Error handling

### Errors from AAPI
Use an `if` statement to check if there is an element named `errors` in the json response body as seen [here](./code_blocks.py#L31-38)

### General HTTP errors
Put the request call inside of a try/except block and specify the relevant exceptions to catch as seen [here](./code_blocks.py#L47-57)

## Password obfuscation

### From a file

Reading the password from a file would typically be combined with command line flags to choose that option.

### Command line arguments with argparse

An additional import line is needed And then the argument parser can be setup like [this](./code_blocks.py#L7-14):
```Python
import argparse

parser = argparse.ArgumentParser(description='Some explanation of what the python script does')
parser.add_argument('-u', '--username', dest='username', type=str, help='Username to login to Control-M/Enterprise Manager')
parser.add_argument('-pf', '--pwfile', dest='pwfile', type=str, help='The file that contains the password to login to Control-M/Enterprise Manager')
parser.add_argument('-h', '--host', dest='host', type=str, help='Control-M/Enterprise Manager hostname')
parser.add_argument('-i', '--insecure', dest='insecure', action='store_const', const=True, help='Disable SSL Certification Verification')
parser.add_argument("--help", action="help", help="show this help message and exit")

args = parser.parse_args()
```

The values passed to each flag are then available like: `args.pwfile`

### Read from the specified file

First, check if the user passed a file the -pf flag, then check if the specified file exists, only after that try to read from the file, as show [here](./code_blocks.py#L21-26):
```Python
import os

if args.pwfile is not None:
    if not os.path.exists(args.pwfile)
        print("Unable to read the specified file, %s, or file does not exist." % args.pwfile)
    else:
        with open(args.pwfile, "r") as f:
            passwd = f.read()
```

Once the password has been used to get a token, the `passwd` variable to be deleted so that the password is no longer in memory. (See [here](./code_blocks.py#L41-42)):
```python
passwd = None
del passwd
```

### Interactive Prompt
If the user didn't specify a password file, then prompting the user is an option (See [here](./code_blocks.py#L27-28)):
```Python
if args.pwfile is not None:
    # See above for this section
    pass
else
    passwd = getpass("Password: ")
```
