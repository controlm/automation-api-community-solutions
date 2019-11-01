#!/usr/bin/env python
# Needed for the print function to work on Python 2 and 3 with one common syntax.
from __future__ import print_function

import sys
import httplib2 as http
import json

try:
    from urlparse import urlparse
except ImportError:
    from urllib.parse import urlparse

# This contains the 3 global variables debug, ignoreCase, and suppressErrors
import  search_global

from search_aapi import *
from search_menu import *
from search_parse import *
from search_tools import *


# Initialize global variables
search_global.init()

# Initialize local variables
endpoint=''
username=''
password=''
ctm=''
agent=''
cmType=''
outputMode='JSON'

token=''

# Store key/value pairs in array
# These are the seach keys and values passed via the command line
key=[]
keyvalue=[]

#
# Get command line parameters and validate them
#

args=len(sys.argv)-1

# If no arguments specified print usage then exit
if args == 0:
   print_usage(0,"exit")

# Check each parameter passed in the command line
pos=0
while (pos < args):
   pos = pos + 1
   if sys.argv[pos] == '-h' or sys.argv[pos] == '--help':
      print_usage(0,"exit")
      continue
   if sys.argv[pos] == '-endpoint':
      if endpoint:
          print_usage(4,sys.argv[pos])
      endpoint = sys.argv[pos + 1] if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-u':
      if username:
          print_usage(4,sys.argv[pos])
      username = sys.argv[pos + 1] if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-p':
      if password:
          print_usage(4,sys.argv[pos])
      password = sys.argv[pos + 1] if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-ctm':
      if ctm:
          print_usage(4,sys.argv[pos])
      ctm = sys.argv[pos + 1] if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-agent':
      if agent:
          print_usage(4,sys.argv[pos])
      agent = sys.argv[pos + 1] if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-type':
      if cmType:
          print_usage(4,sys.argv[pos])
      cmType = sys.argv[pos + 1] if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-key':
      key.append(sys.argv[pos + 1]) if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-value':
      keyvalue.append(sys.argv[pos + 1]) if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-debug':
      search_global.debug = sys.argv[pos + 1] if pos < args else print_usage(1,sys.argv[pos])
      continue
   if sys.argv[pos] == '-s':
      search_global.suppressErrors=True
      continue
   if sys.argv[pos] == '-i':
      search_global.ignoreCase=True
      continue
   if sys.argv[pos] == '-c':
      outputMode = 'color'
      continue
   if sys.argv[pos].startswith("-"):
      print_usage(5,sys.argv[pos])
      continue


# Number of keys should match values
if len(key) != len(keyvalue):
   print_usage(3,"")

# If debug print out -key and -value values
if search_global.debug:
   printCyan('debug keys')
   printCyan(key)
   printCyan('debug values:')
   printCyan(keyvalue)
   print('')


# If debug display required parameters
if search_global.debug:
   printCyan('debug required parameters:')
   if endpoint:
      printCyan('endpoint:' + endpoint)
   if username:
      printCyan('username:' + username)
   if password:
      printCyan('password:****')
   if ctm:
      printCyan('ctm:' + ctm)
   if agent:
      printCyan('agent:' + agent)
   if type:
      printCyan('type:' + cmType)
   printCyan('suppress errors:') 
   printCyan(search_global.suppressErrors)
   printCyan('ignore case:') 
   printCyan(search_global.ignoreCase)
   print('')


# Check if required parameters are set, otherwise exit
if endpoint=='':
   print_usage(2,'-endpoint')
if username=='': 
   print_usage(2,'-username')
if password=='': 
   print_usage(2,'-password')
if ctm=='': 
   print_usage(2,'-ctm')
if agent=='': 
   print_usage(2,'-agent')
if cmType=='':
   print_usage(2,'-type')

# Check if all agents selected; same as no agent filter
if agent == 'ALL':
   agent = ''

# Get token
token = ctmapi_login(endpoint, username, password)

#
# Get list of agents
# 

# Check for agent filter or all
if agent:
   url = endpoint + '/config/server/' + ctm + '/agents?agent=' + agent
else:
   url = endpoint + '/config/server/' + ctm + '/agents'

if search_global.debug in ['3']:
   printCyan('url=' + url)
   print('')

agentData = ctmapi_call(url, 'GET', '', token)

if 'errors' in agentData:
   printRed(json.dumps(agentData))
   ctmapi_logout(endpoint, token)

if search_global.debug:
   printCyan("debug agent list:")
   printCyan(json.dumps(agentData))
   print

# Check if no agents found
if 'agents' not in agentData:
   printRed('No matching agents found')
   ctmapi_logout(endpoint, token)

#
# Loop through each agent and search profiles
#
for agentName in agentData['agents']:
   agent = agentName['nodeid']

   # Skip agents that are not available
   if agentName['status'] == 'Available':

      if search_global.debug:
         printCyan('Searching profiles on agent=' + agent)
         print('')

      urlProfile = endpoint + '/deploy/connectionprofiles?ctm=' + ctm + '&type=' +cmType + '&agent=' + agent
      profileData = ctmapi_call(urlProfile, 'GET', '', token) 

      # Check if error in profiles return
      if 'errors' in profileData:
         if search_global.suppressErrors == False:
            printRed(json.dumps(profileData))
            print('')
      else:
         # search profiles for keys/values
         searchProfiles(profileData, outputMode, key, keyvalue)
   elif search_global.suppressErrors == False:
      printYellow('Warning: agent=' + agent + ' skipped due to unavailable/disabled state')
      print('')

# Logout
ctmapi_logout(endpoint, token)
