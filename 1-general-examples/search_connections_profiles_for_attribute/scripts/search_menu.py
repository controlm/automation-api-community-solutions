#! /usr/bin/env python

import sys
import os

# Dispay usage and exit
def print_usage(err,txt):
   if err == 1:
      print('ERROR: missing expected argument for ' + txt)
   if err == 2:
      print('ERROR: missing required parameter ' + txt)
   if err == 3:
      print('ERROR: number of keys should match number of values')
   if err == 4:
      print('ERROR: parameter ' + txt + ' already specified')
   if err == 5:
      print('ERROR: unknown switch ' + txt)

   if err:
      print('')

   print('')
   print(os.path.basename(sys.argv[0]) + ' uses Control-M Automation API to search supported connection profiles types for attributes')
   print('')
   print('Usage: ' + sys.argv[0] + ' [required parameters] [options]')
   print('Required Parameters:')
   print('-endpoint ENDPOINT                     Automation API endpoint eg https://wla919:8443/automation-api')
   print('-u USERNAME                            EM user credentials')
   print('-p PASSWORD                                               ')
   print('-ctm DATACENTER                        data center name')
   print('                                       no wildcard support')
   print('-agent AGENT                           to specify all agents use ALL or \'*\'')
   print('                                       wildcard supported eg \'dev_*\'')
   print('-type [Hadoop|FileTransfer|Database|SAP|ApplicationIntegrator|Informatica]')
   print('')
   print('Options:')
   print('-debug [1|2|3] ')
   print('-i                                      case insensitive match')
   print('-c                                      pretty/color mode')
   print('-s                                      suppress errors messages')
   print('-key string -value string               multiple key/value pairs supported')
   print('                                        results are returned for any key/value match')
   print('                                        eg -key Host -value localhost -key Username -value root')

   sys.exit()
