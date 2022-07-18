# **Smart Buildings with Azure and Control-M**

This repo contains an example of an IOT/ML predictive maintenance application running on Azure and orchestrated by Control-M.

Control-M is a business application workfow orchestration solution that simplifies the creation, integration and automation of data pipelines across on-premises and cloud technologies.

## Details
IOT Sensor data from smart buildings is combined with traditional infromation about the building and the tenants.
 
### **Architecture**
This is a view of the application components:

![Architecture](Images/SmartBuildingArchitecture.png)

 - **HDInsight** - the Azure Hadoop offering is dynamically launched based upon demand
 - **Control-M Agent** - orchestration worker deployed onto the HDInsight cluster during instantiation
 - **Transfer files** - input IOT data is pushed to the HDInsight cluster after the cluster has initialized
 - **Spark** - Scala Machine Learning algorithms run in Spark
 - **Transfer results** - any data that should persist is pulled out of the HDInsight cluster 
 - **Predict** - Azure Event Grid is used to notify all interested parties
 - **Terminate HDInsight** - decommission cluster to manage costs

### Data
IOT data from buildings is collected and dropped into a Blob container periodically. Control-M watches the container for data arrival. That event triggers the workflow you see in the architecture above.
### HDInsight Cluster 
The HDInsight service launches a Hadoop cluster with the selected components/versions as defined in the dynamic Linked HDI service within the Azure Data Factory (ADF) pipeline. The Spark analytics execution is managed by ADF.
### Other Processing
Data movement is performed by Control-M and its Managed File Transfer facility. 
The ML portion including the analytics is [available in this repo](https://github.com/werowe/preventiveMaintenanceLogitReg).
Notification to interested parties is performed via text messages using Twilio.