# Documentation:  search_parse.py

search_parse.py contains all functions and methods used to traverse a profile in JSON format.  It also perform matches for key/value pairs.
The default output is JSON format.  A more readable and color coded output is avaiable with the *-c* switch.

## Ensure the json key order is preserved.  This important since "Type" should always be the first attribute in a profile. Also profile comparisions using diff or comp would not work to detect changes.
```
from collections import OrderedDict
```
## Set the key/value pair values to lower then upper case.  This is used for case insensitive comparisions.  This a rudimentary implemention that may not suppport non-English characters or accents.
```
def normalizeList(x):
   for i in range(len(x)):
      x[i][0] = x[i][0].lower().upper()
      x[i][1] = x[i][1].lower().upper()
```

## Compare the key and value to ones in a list to be found.
```
def pairMatch(a, b, c):
   ...
   if search_global.ignoreCase==True:
```

## Traverse the JSON recursively.
```
def tree(data, pairsToMatch=[]):
```

## Traverse the JSON recursively and print out values in non-JSON and added color where supported.
```
def treeColor(data, depth, pairsToMatch=[]):
```

## Main function to perform search of profiles in JSON format
```
def searchProfiles(data, outputmode, key=[], value=[]):
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
