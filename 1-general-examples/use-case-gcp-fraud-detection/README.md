# **Google Cloud Servicess with Control-M**

This example illustrates usage of Control-M to orchestrate a data pipeline in a Google Cloud PLatform environment. 

## Details
The components include data arriving in Google Storage, processed with Google Dataflow and inserted into BiqQuery.

### **Artifacts**
A brief description of the contents:

 - **cp_DFLOW-sample.json** - a connection profile for Google Dataflow.
 - **cp_jobgcp.json** - a connection profile for Google Storage, used by Control-M's Managed File Transfer.
 - **cp_jog-BQ.json** - connection profile for BgQuery.
 - **define-sless-queues.sh** - connection profile for Google Dataflow using a default service account of the virtual machine on which the Control-M job executes
 - **driver-BigQuery.json** - JDBC driver provided by Google, for SQL access to BigQuery.
 - **jog-mc-gcp-fraud.json** - the definition for the tasks that that make up this orchestration. 

 For any questions, please contact the author at joe_goldberg@bmc.com.