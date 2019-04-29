# **Kubernetes and Control-M**

The contents of this folder implement a Customer 360 View and Sentiment Analysis application to demonstrate how Control-M is used to manage application workflow in a Kubernetes environment. 

## **Use Case**

A financial services organization wishes to expand its portfolio management business by tracking individuals that tweet about investments, financial markets and the services they get from their existing providers of financial advice. When a potential tweet is retrieved, the Geo-location data, if present, is used to identify if the individual is an existing or a potential new customer. In either case, it is also desirable to determine if this individual is a member of a family that is currently not being managed as a single unit. Depending on the tweet contents and what can be learned about this individual, a personalized marketing offers may be sent. If the tweet is a complaint, a customer service representative may reach out or if new information is gathered that can assist in combining this individual with others, perhaps two partners living at the same address, internal operations can be streamlined to offer improved service to the entire family.

Control-M orchestrates this application because there are components 

## **Architecture**
This is a view of the application components:

![Architecture](images/Cust360Arch.png)

 - Kubernetes Cluster - Bitnami Sandbox on AWS running Kubernetes 1.14
 - Control-M Agent - Running as a DaemonSet, managing application Workflows
 - AWS S3 - Geo-Location updates are dropped in a bucket periodically
 - Kafka - Used as a communication transport for twitter data 
 - Snowflake - Used as a Data Lake to aggregate all the data components used in the implementation
 - CRM - this System of Record contains customer and portfolio data
 The artifacts are arranged in the following folders:
 
 - Application:	Components of application that pulls form Kafka topic and categorizes incoming tweets as customer or not
 - CTM Machine:	Workflow definitions and other artifacts used by Control-M
 - Kubernetes Machine:	K8S YAML manifests for defining and managing Kubernetes artifacts like the Control-M Agent DaemonSet, Service Account and K8S Job manifests
 - PythonApp:	Components of application that pulls twitter data and produces to Kafka topic

The Geo-Location data set for addresses in the United States  is available from OpenAddresses and hosted on Kaggle.com.

## Details
Many of the application components run in a Kubernetes cluster but there is processing and data outside the cluster. 
### Cluster 
Tweets are retrieved by bmctwitter.py and published to a Kafka topic. Each pod processes a specific geographic quadrant. In this sample, we are using the State of Connecticut and splitting it into Northeast, Northwest, Southeast and Southwest.
KafkaSnowflake.py subscribes to the same Kafka topic and pushes data to Snowflake.
The Control-M agent runs on the Kubernetes cluster as a DaemonSet. The agent connects to whichever Control-M environment specified via a set of .secret files which contain a URL and credentials. The credential files are mounted to the agent Pod and provide an easy way to update the information.  Only the nodes labelled with "WorkflowManager: controlm" run an instance of the agent.
### Other Processing
Geo-Location data is updated periodically when new buildings or subdivisions are built. The data arrives in an S3 bucket. Control-M "watches" this bucket and when data arrives, pushes updates to Snowflake.
Information about customers and their current portfolio subscriptions is extracted on a regular basis and used to update that same data in Snowflake.
A Control-M server runs on an EC2 instance. This infrastructure coordinates all the activities of the agent running in the K8S cluster and the other tasks running outside the cluster. 