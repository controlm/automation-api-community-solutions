# Scripts

This directory contains 2 sample scripts ServerAgentConnectivityTest.py and UpdateAuthorizedServer.sh.


## 
* [ServerAgentConnectivityTest.py](./ServerAgentConnectivityTest.py)

    This example demonstrates how to use Automation API to
     - check the connectivity between Control-M/Server and Control-M/Agents
     - print out the Control-M/Agents status
    
    The Control-M/Agent status can be
    . Available
    . Unavailable
    . Disable
    . Discovering
    
    The document  [code-doc-ServerAgentConnectivityTest.md](./code-doc-ServerAgentConnectivityTest.md) explains the functionality of individual sections of this script. 
    
* [UpdateAuthorizedServer.sh](./UpdateAuthorizedServer.sh)

    This example demonstrates how to use Automation API to 
     - Update the Authorized Control-M/Server list to desired value in Control-M/Agent
     
    The Authorized Control-M/Server list determines which Control-M/Server can connect to the current Control-M/Agent.
    
    The document [code-doc-UpdateAuthorizedServer.md](./code-doc-UpdateAuthorizedServer.md) explains the functionality of individual sections of this script. 

