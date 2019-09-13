# Documentation:  search_tools.py

search_tools.py contains functions used by the tool but are not necessary it's main function.

# Functions to print text in color where supported by wrapping ANSI escape codes to print statements.
```
def printGreen(s): print("\033[92m {}\033[00m" .format(s)) 
def printRed(s): print("\033[91m {}\033[00m" .format(s))
def printCyan(s): print("\033[96m {}\033[00m" .format(s)) 
def printYellow(s): print("\033[93m {}\033[00m" .format(s)) 
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
