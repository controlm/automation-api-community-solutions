# Documentation:  search_menu.py

search_menu.py only has 1 method *print_usage* which prints any error messages, prints the usage, and exits

## print_usage
```
def print_usage(err,txt):
   if err == 1:
      print('ERROR: missing expected argument for ' + txt)
   ...
   print('')
   print(os.path.basename(sys.argv[0]) + ' uses Control-M Automation API to search supported connection profiles types for attributes')
   ...
   sys.exit()
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
