# Reusable Python code blocks

## Imports
Standard import that are likely needed for any Python script calling AAPI:
[here](./code_blocks.py#L4-5)
```Python
import requests
import json
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

An additional import line is needed And then the argument parser can be setup like [this](./code_blocks.py#L13-16):
```Python
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser(description='Updates Authorized Control-M/Servers list in multiple Agents')
parser.add_argument('-tf', '--tokenfile', dest='tokenfile', type=str, help='File that contains the API Key', required=False)
args = parser.parse_args()
```

The values passed to each flag are then available like: `args.pwfile`

### Read from the specified file

First, check if the user passed a file the -tf flag, then check if the specified file exists, only after that try to read from the file, as shown [here](./code_blocks.py#L18-27)
```Python
import os

if args.tokenfile is not None:
    if not os.path.exists(args.tokenfile):
        print("Unable to read the specified file, %s, or file does not exist." % args.tokenfile)
    else:
        with open(args.tokenfile, "r") as f:
            apitoken = f.read()
            apitoken = apitoken.rstrip(' \t\r\n\0')
else:
    apitoken = getpass.getpass("API Token: ")
```

Once the password has been used to get a token, the `passwd` variable to be deleted so that the password is no longer in memory. (See [here](./code_blocks.py#L41-42)):
```python
passwd = None
del passwd
```
If the user didn't specify a token file, then prompting the user is an option

