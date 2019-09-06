# Documentation:  search_aapi.py

The search_aapi.py contains functions and methods that interact with the Control-M Automation API.

## Ensure the json key order is preserved.  This important since "Type" should always be the first attribute in a profile. Also profile comparisions using *diff* or *comp* would not work to detect changes.
```
from collections import OrderedDict# Documenation: 
```
## Login to Automation API and return token
```
def ctmapi_login (endpoint, username, password): 
   token = ''
   ...
```

## Logout of Automation API and exit script
```
def ctmapi_logout (endpoint, token):
   ...
   sys.exit()
```


## Perform all calls to Automation API and return results.  Even the *ctmapi_login* and *ctmapi_logout* call this function.
```
def ctmapi_call(url, method, body, token):
   ...
   return data
```

## Table of Contents
* [Main README](../README.md)
* [Python Scripts & Documentation](./scripts)
* Additional Documentation:
    * [search_aapi.py](search_aapi.md)
    * [search_global.py](search_global.md)
    * [search_menu.py](search_menu.md)
    * [search_parse.py](search_parse.md)
    * [search_profiles.py](search_profiles.md)
    * [search_tools.py](search_tools.md)