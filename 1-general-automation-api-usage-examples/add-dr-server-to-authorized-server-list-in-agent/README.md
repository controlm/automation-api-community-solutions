## **Requirement:**

The &quot;Authorized Control-M/Server Hosts&quot; field under ctmagcfg in Control-M/Agent determines which Control-M/Server can connect to this Control-M/Agent. When the Control-M/Server DR is setup,  the DR Control-M/Server needs to be added into this filed, so when the Prod Control-M/Server goes down and DR takes over, the DR can communicate with the Control-M/Agents. Control-M Automation API offers the API of &quot;ctm config server:agent:param::set&quot; to automate and orchestrate the process.


## **Scenario:**

We have our production Control-M Server up and running, its hostname is ctmsprod. For business continuous purpose, we need to setup a DR machine for this ctmsprod. The hostname of DR is ctmsdr. All the data will be automatically synced from ctmsprod to ctmsdr. When ctmsprod goes down, the ctmsdr will take over, so the ctmsdr must be authorized at Control-M/Agents.

Basic Workflow for this scenario is


![workflow for scenario](/Images/Workflow.PNG)


## **Prerequisites**

- N/A



## **Implementation**

Step 1 - &quot;Setup the DR Control-M/Server with its own hostname&quot;

- Setup your DR accordingly, if you need assistance, please contact BMC Support.

Step 2 - &quot;Add DR Control-M/Server to the Authorized Control-M/Server list at Agents&quot;
- To perform this,  the following Automation APIs are invoked in UpdateAuthorizedServer.sh:

```
2-1 : Define the Automation API server endpoint 
ctm env add endpoint https://$AAPI_HOST:$AAPI_PORT/automation-api $AAPI_USER $AAPI_PASSWORD && ctm env set endpoint

2-2 : Add DR Control-M/Server to the Authorized Control-M/Server list
ctm config server:agent:param::set $CTM_SERVER $AGENT "CTMPERMHOSTS" "$DESIRED_CTM_SERVER"
```

Step 3 - &quot;Perform the DR test(optional)&quot;

- You are advised to do a DR testing to ensure DR can connect to all its associated Agents. If you need assistance, please contact BMC Support.