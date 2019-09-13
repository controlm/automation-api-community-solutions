#! /usr/bin/env python
# Needed for the print function to work on Python 2 and 3 with one common syntax.
from __future__ import print_function

import sys
from collections import OrderedDict
import json
import search_global
from search_tools import *


# # This module has functions to search the json of the profile
#

# Normalize values in list by making lower case then upper case.
# This will not work 100% for non-English langauges
def normalizeList(x):
   for i in range(len(x)):
      x[i][0] = x[i][0].lower().upper()
      x[i][1] = x[i][1].lower().upper()


# Find matching [ 'a','b' ] in list c of lists
# eg find ['a','b'] in [ [ 'a','b'] , ['c','d'], '['e','f'] ]
def pairMatch(a, b, c):
   # If ignoring case, compare everything in uppercase
   if search_global.ignoreCase==True:
      a = str(a).lower().upper()
      b = str(b).lower().upper()
      normalizeList(c)

   if [ a, b ] in c:
      return True
   else:
      return False


# Traverse a json/dict
# This is use to search the profile in json format recursively.
# Returns True if any match is found 
def tree(data, pairsToMatch=[]):
   leafpair = []

   if isinstance(data ,dict):
      for a, b in data.items():
         if isinstance(b, dict):
            if tree(b,  pairsToMatch):
               return True
         else:
            if pairMatch(a, b, pairsToMatch):
               return True
   else:
       return False

   return False


# Traverse a json/dict
# This is use to search the profile in json format recursively.
# This mode displays the attributes with colors if supported
def treeColor(data, depth, pairsToMatch=[]):
   leafpair = []
   result = ''

   # indent is use to indent each level by a few spaces
   indent=''
   for i in range(depth):
      indent=indent + '  '

   if isinstance(data ,dict):
      for a, b in data.items():
         if isinstance(b ,dict):
            if depth == 0:
               printGreen('----- PROFILE -----')
            print(indent,a,'=')
            treeColor(b, depth+1, pairsToMatch)
         else:
            print(indent,a,'=',b, end='')
            if pairMatch(a, b, pairsToMatch):
               printGreen('                    <----- MATCH -----')
            else:
               print('')
      if depth == 0:
         print('')
   else:
       print(indent,data)


# Search profiles in json data
# This is the main functions that performs the search request
def searchProfiles(data, outputmode, key=[], value=[]):
   dataDisplay = []
   profile = []
   pairsToMatch = []

   # Create a list of key/value search pairs
   # This will be used with pairMatch
   i=0
   for k in key:
      pair = [ key[i], value[i] ] 
      pairsToMatch.append(pair)
      i = i + 1

   # If debug display key/value pairs
   if search_global.debug in ['3']:
      print('pairsToMatch=', pairsToMatch)
      print('')

   # Traverse JSON. Add profile to list to display if any matches.
   # For color mode, print the traveral with treeColor()
   for x,y in data.items():
      profile = []
      # add to list to print if no filter or match
      if len(pairsToMatch) == 0 or tree(data[x], pairsToMatch):
         # rebuild json and add to list
         profile.append({x : data[x]})
         dataDisplay.append(profile)

         # display current profile in color/pretty mode
         if outputmode == 'color':
            treeColor(profile[0], 0, pairsToMatch)

   # print results if using default 'JSON' outputMode
   if outputmode == 'JSON':
      if(len(dataDisplay)):
         results = {"results": dataDisplay}
         print (json.dumps(results, indent=3))
