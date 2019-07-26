## **Requirement:**

A server farm is also known as a server cluster which contains a set of many servers interconnected together and provides the combined computing power by simultaneously executing one or more applications or services. It delivers scalable throughput by dynamically scale-in and scale-out nodes in the farm, it has been proved as a great success in E-commerce, Big Data, Machine Learning, AI, and other large-scale or scalable web compute needs. Control-M Automation API can enable users to effectively, seamlessly and dynamically manage the job workload among the servers. The data backup in the node of server farm is an essential practice, and it can also be very challenging and requires many manual interferences like Control-M/Agent deployment at new node, Agent registration at CCM, job deployment, etc. With Automation API, it will eliminate those manual interference and orchestrate the process.

## **Scenarios:**

An E-commerce company has a large-scale webserver farm which serves their online shopping service. Their webserver farm has auto scaling setting as below

- --Minimum number of nodes in farm: 5
- --Maximum number of nodes in farm: 10
- --Scale up increment: 1

This indicates their server farm will have at least 5 nodes up and running, at most 10 nodes, it will scale in the node by 1 when scaling triggers.

The company has a backup script which backup all the transaction data to a SAN disk. 

The company has a HostGroup of &quot;ServerFarmHostGroup&quot; which contains all the nodes in the farm. All of the scaled-in node needs to be automatically registered into this HostGroup, and all of the scaled-out node needs to be automatically deregistered from this HostGroup as well.

The company has a Control-M job which invokes the backup script every day at 1:00AM to back up the transaction data, and this Control-M job is associated with the &quot;ServerFarmHostGroup&quot; hostgroup. And the feature of &quot;RunOnAllAgentsInGroup&quot; is enabled, thus the job will be submitted to all the hosts in group of &quot;ServerFarmHostGroup&quot;.

The company needs to design a Control-M solution by Automation API which can

- --Automatically deploy the Control-M/Agent on new node booting up
- --Automatically register the new Control-M/Agent into the &quot;ServerFarmHostGroup&quot;
- --The backup Control-M job should automatically be submitted to the new Control-M/Agent
- --The Control-M/Agent should be automatically dereigistered from &quot;ServerFarmHostGroup&quot; when the node is stopped

Basic Workflow for this scenario is



![workflow for scenario](/Images/Workflow.PNG)


## **Prerequisites**

- HostGroup of &quot;ServerFarmHostGroup&quot; is created
- Adding DeployAgent.sh into Linux Auto-Start service
- Adding DecommissionAgent.sh into Linux Auto-Stop service



## **Implementation**

Step 1 - &quot;Control-M job is scheduled to run at HostGroup&quot;

- Create a job def in Json which can be deployed by Automation API to run at hostgroup

 [Jobs.json](./ctmjobs/Jobs.json)


Step 2 - &quot;New node is added into the server farm as Scale-in triggers&quot;

Step 3 - &quot;Linux Auto-Start service invokes a script to deploy Control-M/Agent&quot;

- To perform this,  the following Automation APIs are invoked in DeployAgent.sh:
```
3-1 : Define the Automation API server endpoint 
ctm env add endpoint https://$AAPI_HOST:$AAPI_PORT/automation-api $AAPI_USER $AAPI_PASSWORD && ctm env set endpoint

3-2 : Install Control-M/Agent
ctm provision image Agent.Linux

3-3 : Register Control-M/Agent in Control-M/Server
ctm provision setup $CTM_SERVER $CTM_AGENT $CTM_AGENT_PORT -e $CTM_ENV

3-4 : Add Control-M/Agent into HostGroup
ctm config server:hostgroup:agent::add $CTM_SERVER $CTM_HOSTGROUP $CTM_AGENT
```


![workflow for scenario](/Images/LogicOfDeployAgent.PNG)









Step 4 - &quot;Node is removed from the server farm as Scale-out triggers&quot;

Step 5 - &quot;Linux Auto-Stop service invokes a script to decommission Control-M/Agent &quot;

- To perform this,  the following Automation APIs are invoked in DecommissionAgent.sh:
```
5-1 : Remove Control-M/Agent from HostGroup 
ctm config server:hostgroup:agent::delete $CTM_SERVER $CTM_HOSTGROUP $AGENT_ALIAS -e $CTM_ENV

5-2 : Unregister Control-M/Agent from Control-M/Server
ctm config server:agent::delete $CTM_SERVER $AGENT_ALIAS
```



![workflow for scenario](/Images/LogicOfDecommissionAgent.PNG)



## Table of Contents

1. [Images](./Images)
2. [Scripts](./Scripts)
2. [Ctmjobs](./ctmjobs)