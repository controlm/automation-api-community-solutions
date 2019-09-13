# Documentation:  search_global.py

search_global.py contains all the global variables in in the project.  init() should be called to initalize the variables only once from the main program *search_profiles.py*.
This is mainly for variables used for debug, ignoring case, and suppressing error messages without having to add extra parameters to functions and methods.

## initialize variables
```
def init():
   global debug
   global ignoreCase
   global suppressErrors

   debug=''
   ignoreCase=False
   suppressErrors=False
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