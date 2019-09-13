#! /usr/bin/env python

import sys
import httplib2 as http
from collections import OrderedDict
import json

try:
    from urlparse import urlparse
except ImportError:
    from urllib.parse import urlparse

import search_global 
from search_tools import *

# This module contains the functions login, logout, and call functions of Autmation API

# Login to Automation API and get token
def ctmapi_login (endpoint, username, password): 
   token = ''

   urlLogin = endpoint + '/session/login'
   body = '{"username":"' + username + '","password":"' + password + '"}'

   loginData = ctmapi_call(urlLogin, 'POST', body, token)

   if 'token' in loginData:
      token = loginData['token']
      if search_global.debug:
         printCyan('debug token:')
         printCyan('token=' + token)
         print('')
      return token
   else:
      printRed(json.dumps(loginData))
      sys.exit()

# Logout of Automation API and exit script
def ctmapi_logout (endpoint, token):
   urlLogout = endpoint + '/session/logout'
   logoutData = ctmapi_call(urlLogout, 'POST', '', token)
   sys.exit()

# Perform calls to Automation API and return results
def ctmapi_call(url, method, body, token):
   headers = {
       'Accept': 'application/json',
       'Content-Type': 'application/json; charset=UTF-8'
   }

   if token:
       headers['Authorization'] = 'Bearer ' + token

   h = http.Http()
   h = http.Http(".cache", disable_ssl_certificate_validation=True)

   target = urlparse(url)

   if search_global.debug in ['3']:
      printCyan('target' + str(target))
      print('')

   try:
      response, content = h.request(target.geturl(),method,body,headers)
   except:
      return '{ "errors" : [ "message" : "Failed to connect to ' + url +'" ] }'

   try:
      data = json.loads(content,object_pairs_hook=OrderedDict)
   except:
      return '{ "errors" : [ "message" : "ERROR: Bad response for ' + url +'" ] }'

   if 'errors' in data:
      if search_global.suppressErrors == False:
         printRed(json.dumps(content.decode()))

   if search_global.debug:
      printCyan(json.dumps(content.decode()))
      print('')

   return data
