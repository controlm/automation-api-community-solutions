# Connection Profile Types Reference

A catalog of every centralized connection profile type documented by BMC ([source](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles.htm)), with the field(s) that carry an endpoint (host/URL), for deciding which types `resolve_connection_profile_endpoint` could plausibly be extended to support.

> **These are BMC documentation samples, not verified against a live CCP** - unlike everything else in `CTM_ENGINEER.md`, which was only added after confirming against a real profile on `ctm.werkstatt.local`. Treat this file as "where to look next," not as ground truth to code against directly. Before adding support for any type here, fetch a real CCP of that type and confirm the field name and shape match what's shown below.

**Already implemented and live-verified:** `FileTransfer:SFTP`, `FileTransfer:FTP` (both via `HostName`/`Port`), `Database:PostgreSQL` (via `Host`/`Port`, plus the other DB engines in `DEFAULT_PORTS_BY_CCP_TYPE`). `FileTransfer:Local`, `FileTransfer:S3:Amazon`, and `FileTransfer:GCS` are confirmed to have **no** literal endpoint (SDK/API-based) and correctly skip.

**Reading the "Endpoint field(s)" column:** many entries are a `*URL` field pointing at a fixed, multi-tenant vendor API endpoint (e.g. `https://login.microsoftonline.com`, `https://management.azure.com`, regional AWS/GCP service endpoints) - the same for every BMC customer using that plugin, not something specific to this Control-M environment. Testing reachability to those proves general internet/proxy connectivity, not anything about *this customer's* infrastructure - a materially weaker signal than testing an SFTP/Database/self-hosted server's actual `Host`. Entries with a plain `Host`/`HostName` (or a customer-owned domain/IP) are the ones closest in spirit to what this module already tests.

## Application Workflow

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_AppWorkflows.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Airflow:Standalone` | `Host`: `dba-airflow-12` |
| `ConnectionProfile:Airflow:GoogleComposer` | `BaseURL`: `http://akjsdlksajdksad` |
| `ConnectionProfile:Apache Airflow` | `Airflow URL`: `https://localhost` |
| `ConnectionProfile:Astronomer` | `Deployment URL`: `https://clybeh1ok01ke01k6wr9szi10.astronomer.run/dns2rtpk` |
| `ConnectionProfile:AWS MWAA` | `AWS MWAA URL`: `https://env.airflow.AwsRegion.amazonaws.com` |
| `ConnectionProfile:AWS Step Functions` | `Step Functions URL`: `https://states.AWSRegion.amazonaws.com` |
| `ConnectionProfile:Azure Logic Apps` | `Azure Login url`: `https://login.microsoftonline.com` |
| `ConnectionProfile:GCPComposer` | *(sample didn't parse cleanly)* |
| `ConnectionProfile:GCP Workflows` | `GCP API URL`: `https://workflowexecutions.googleapis.com` |

## Backup and Recovery

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_Backup.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:AWS Backup` | `AWS Backup URL`: `https://backup.{{AWSRegion}}.amazonaws.com.` |
| `ConnectionProfile:AWS DataSync` | `AWS Logs URL`: `https://logs.AwsRegion.amazonaws.com`<br>`AWS DataSync URL`: `https://datasync.AwsRegion.amazonaws.com` |
| `ConnectionProfile:Azure Backup` | `Azure Management URL`: `https://management.azure.com`<br>`Azure Login URL`: `https://login.microsoftonline.com` |
| `ConnectionProfile:Rubrik` | `Rubrik URL`: `https://xxxx.my.rubrik.com` |
| `ConnectionProfile:Veeam Backup` | `URL`: `https://{{EMServer}}:9398` |
| `ConnectionProfile:NetBackup` | `Endpoint URL`: `https://MasterServerName:1556` |

## Business Intelligence and Analytics

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_Business.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:AWS QuickSight` | `AWS QuickSight URL`: `https://quicksight.us-east-1.amazonaws.com` |
| `ConnectionProfile:Microsoft Power Automate` | `Power Automate URL`: `https://api.flow.microsoft.com/providers/Microsoft.Proces...` |
| `ConnectionProfile:Microsoft Power BI` | `API URL`: `https://api.powerbi.com/v1.0/myorg/` |
| `ConnectionProfile:Microsoft Power BI SP` | `Power BI URL`: `https://api.powerbi.com/v1.0/myorg/` |
| `ConnectionProfile:Qlik Cloud` | `Qlik API URL`: `qlikcloud.com/api/v1` |
| `ConnectionProfile:Tableau` | `Tableau URL`: `https://prod-useast-b.online.tableau.com` |

## CI/CD

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_CICD.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Atlassian Bitbucket` | `Bitbucket REST URL`: `https://api.bitbucket.org/2.0` |
| `ConnectionProfile:Azure DevOps` | `Azure DevOps URL`: `https://dev.azure.com` |
| `ConnectionProfile:CircleCI` | `CircleCI URL`: `https://circleci.com/api/v2` |
| `ConnectionProfile:GitHub Actions` | `GitHub URL`: `https://api.github.com` |
| `ConnectionProfile:Jenkins` | `Jenkins URL`: `https://vl-tlv-ctm-bl30.adprod.bmc.com` |

## Cloud Computing

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_CloudCompute.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:AWS` | *none found* |
| `ConnectionProfile:AWS Batch` | `Batch URL`: ` https://batch.{{region}}.amazonaws.com` |
| `ConnectionProfile:AWS EC2` | *none found* |
| `ConnectionProfile:AWS Lambda` | `Lambda URL`: `https://lambda.{{region}}.amazonaws.com` |
| `ConnectionProfile:Azure` | *none found* |
| `ConnectionProfile:Azure App Services WebJobs` | `Login URL`: `https://login.microsoftonline.com`<br>`Management URL`: `https://management.azure.com` |
| `ConnectionProfile:Azure Batch Accounts` | `Azure AD url`: `https://login.microsoftonline.com`<br>`Batch Resource url`: `https://batch.core.windows.net/` |
| `ConnectionProfile:AzureFunctions` | `Azure Login url`: `https://login.microsoftonline.com` |
| `ConnectionProfile:Azure Functions` | `Azure Login url`: ` https://login.microsoftonline.com` |
| `ConnectionProfile:Azure VM` | `Azure Login URL`: `https://login.microsoftonline.com`<br>`Azure Login url`: `https://login.microsoftonline.com` |
| `ConnectionProfile:Azure VM Scale Sets` | `Azure Login URL`: `https://login.microsoftonline.com`<br>`Virtual Machine Scale Set URL`: `https://management.azure.com` |
| `ConnectionProfile:GCP Batch` | `Batch URL`: `https://batch.googleapis.com` |
| `ConnectionProfile:GCP Eventarc` | `Eventarc URL`: `https://eventarc.googleapis.com` |
| `ConnectionProfile:GCP Functions` | `GCP API URL`: `https://cloudfunctions.googleapis.com` |
| `ConnectionProfile:GCP VM` | `GCP API URL`: `https://compute.googleapis.com/compute` |
| `ConnectionProfile:OCI Functions` | `OCI Functions URL`: `https://functions.ux-phoenix-1.oci.oraclecloud.com` |
| `ConnectionProfile:OCI VM` | `OCI Instances URL`: `https://iaas.us-phoenix-1.oraclecloud.com/20160918` |
| `ConnectionProfile:VMwareByBroadcom` | `vCenter URL`: `https://VCenter.domain.com` |

## Container Orchestration

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_Container.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:AWS ECS` | `AWS ECS URL`: `https://ecs.us-east-1.amazonaws.com`<br>`Cloud Watch URL`: `https://logs.us-east-1.amazonaws.com` |
| `ConnectionProfile:AWS App Runner` | `AWS App Runner URL`: `https://apprunner.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:Azure Container Instances` | `Login URL`: `https://login.microsoftonline.com`<br>`Management URL`: `https://management.azure.com` |
| `ConnectionProfile:GCP Cloud Run` | `Cloud Run URL`: `https://run.googleapis.com` |
| `ConnectionProfile:Kubernetes` | `Spec Endpoint URL`: `my.com`<br>`Kubernetes Cluster URL`: `https://kubernetes.default.svc` |

## Data Integration

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_DataIntegration.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Airbyte` | `Airbyte URL`: `https://api.airbyte.com` |
| `ConnectionProfile:Apache NiFi` | `NiFi URL`: `https://localhost` |
| `ConnectionProfile:AWS AppFlow` | `AWS Appflow URL`: `https://appflow.Region.amazonaws.com` |
| `ConnectionProfile:AWS Database Migration Service` | `AWS DMS URL`: `https://dms.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:AWS Glue` | `Glue url`: `glue.eu-west-2.amazonaws.com` |
| `ConnectionProfile:AWS Glue DataBrew` | `AWS Logs URL`: `https://logs.{{AWSRegion}}.amazonaws.com`<br>`AWS API Base URL`: `https://databrew.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:AWS RDS` | `AWS RDS URL`: `https://rds.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:ADF` | *none found* |
| `ConnectionProfile:Boomi` | *none found* |
| `ConnectionProfile:Dataiku` | `Dataiku DSS URL`: `https://dss-cd513f6d-df4ddeae-dku.us-east-1.app.dataiku.io` |
| `ConnectionProfile:Fivetran` | `Fivetran Base URL`: `https://api.fivetran.com` |
| `ConnectionProfile:GCPDF` | `GCP Data Fusion URL`: `https://datafusion.googleapis.com` |
| `ConnectionProfile:GCP Dataplex` | `GCP Dataplex URL`: `https://dataplex.googleapis.com ` |
| `ConnectionProfile:GCP Dataprep` | `GCP Dataprep URL`: `https://api.clouddataprep.com` |
| `ConnectionProfile:IBM DataStage Windows` | *none found* |
| `ConnectionProfile:IBM DataStage Linux` | *none found* |
| `ConnectionProfile:Informatica` | `Host`: `InformaticaHost` |
| `ConnectionProfile:Informatica CS` | `Login URL`: `https://dm-us.informaticacloud.com`<br>`Base URL`: `https://usw5.dm-us.informaticacloud.com` |
| `ConnectionProfile:Matillion` | `Matillion ETL Instance URL`: `http://172.166.59.666` |
| `ConnectionProfile:Microsoft Fabric` | `Login URL`: `https://login.microsoftonline.com`<br>`Fabric URL`: `https://api.fabric.microsoft.com` |
| `ConnectionProfile:OCI Data Integration` | `OCI Data Integration URL`: `https://dataintegration.us-phoenix-1.oci.oraclecloud.com` |
| `ConnectionProfile:OCI Data Transform Prototype` | `OCI Data Transform URL`: `https://{{Hostname}}.adb.{{Region}}.oraclecloudapps.com`<br>`Hostname`: `g6e*******4-cify**********` |
| `ConnectionProfile:Oracle Fusion Cloud ESS` | `Oracle Fusion Cloud ESS URL`: `https://fusion_env.fa.ocs.oraclecloud.com` |
| `ConnectionProfile:SAP Integration Suite` | `Authentication URL`: `https://if-account-7bnb4a1p.authentication.us01.hana.onde...`<br>`API URL`: `https://if-account-7bnb4a1p.it-cpi047.cfapps.us01.hana.on...` |
| `ConnectionProfile:Talend Data Management` | `API URL`: `https://api.eu.cloud.talend.com`<br>`Talend URL`: `https://api.eu.cloud.talend.com` |
| `ConnectionProfile:Talend OAuth` | `Talend API URL`: `https://api.eu.cloud.talend.com` |
| `ConnectionProfile:TRIFACTA` | `Trifacta URL`: `https://cloud.trifacta.com` |

## Data Processing and Analytics

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_DataProcessing.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:AWS Athena` | `AWS API Base URL`: `https://athena.us-east-1.amazonaws.com` |
| `ConnectionProfile:AWS Data Pipeline` | `Data Pipeline URL`: `https://datapipeline.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:AWS DynamoDB` | `AWS Backup URL`: `https://dynamodb.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:AWS EMR` | *(sample didn't parse cleanly)* |
| `ConnectionProfile:AWS Redshift` | `AWS Base URL`: `https://redshift-data.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:Azure AI Foundry` | `Foundry URL`: `https://<resource-name>.services.ai.azure.com`<br>`Azure Login url`: `https://login.microsoftonline.com` |
| `ConnectionProfile:Azure Databricks` | `Databricks url`: `https://adb-1111211144444680.0.azuredatabricks.net`<br>`Azure Login url`: `https://login.microsoftonline.com` |
| `ConnectionProfile:Azure HDInsight` | *none found* |
| `ConnectionProfile:Azure Synapse` | `Azure AD url`: `https://login.microsoftonline.com`<br>`Synapse url`: `https://ncu-if-synapse.dev.azuresynapse.net` |
| `ConnectionProfile:DataAssurance:Database:MySQL` | `HostName`: `abc-efg-hij8km` |
| `ConnectionProfile:DataAssurance:File:Csv` | *none found* |
| `ConnectionProfile:Databricks` | `Databricks workspace url`: `https://adb-6943019930999707.7.azuredatabricks.net` |
| `ConnectionProfile:DBT` | `DBT URL`: `https://cloud.getdbt.com` |
| `ConnectionProfile:GCP BigQuery` | `BigQuery URL`: `https://bigquery.googleapis.com` |
| `ConnectionProfile:GCP DataFlow` | `DataFlow URL`: `https://dataflow.googleapis.com` |
| `ConnectionProfile:GCP Dataproc` | `Dataproc URL`: `https://dataproc.googleapis.com` |
| `ConnectionProfile:Hadoop` | *none found* |
| `ConnectionProfile:OCI Data Flow` | `OCI Data Flow URL`: `https://dataflow.region.oci.oraclecloud.com` |
| `ConnectionProfile:Snowflake` | `Snowflake URL`: `https://{{AccountID}}.{{Region}}.snowflakecomputing.com` |
| `ConnectionProfile:Snowflake IdP` | `IDP URL`: `https://****************` |
| `ConnectionProfile:Snowflake Cortex AI` | `Snowflake URL`: `https://{{AccountID}}.{{Region}}.snowflakecomputing.com`<br>`Identity Provider URL`: `https://login.microsoftonline.com/92b796c5-5839-40a6-8dd9...` |

## Database Management

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_Databases.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Database:DB2` | `Host`: `DB2Host` |
| `ConnectionProfile:Database:JDBC` | `Host`: `PGSQLHost` |
| `ConnectionProfile:Database:MSSQL` | `Host`: `MSSQLHost` |
| `ConnectionProfile:Database:MSSQL:SSIS` | `Host`: `localhost` |
| `ConnectionProfile:Database:Oracle:SID` | `Host`: `OracleHost` |
| `ConnectionProfile:Database:Oracle:ServiceName` | `Host`: `OracleHost` |
| `ConnectionProfile:Database:Oracle:ConnectionString` | *none found* |
| `ConnectionProfile:Database:PostgreSQL` (implemented) | `Host`: `PostgreSQLHost` |
| `ConnectionProfile:Database:Sybase` | `Host`: `SybaseHost` |

## Enterprise Resource Planning (ERP)

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_ERP.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:OEBS` | *none found* |
| `ConnectionProfile:PeopleSoft` | *none found* |
| `ConnectionProfile:SAP` | `ApplicationServerLogon.Host`: `localhost` |
| `ConnectionProfile:SAP BTP Scheduler` | `SAP Authentication URL`: `https:/<Domain Name>.authentication.<Region>.hana.ondeman...`<br>`Trigger URL`: ` https://jobscheduler-rest.cfapps.<Region>.hana.ondemand.com` |
| `ConnectionProfile:SAP IBP` | `Host`: `my1111-api.scmibp1.ondemand.com`<br>`Service URL`: `/sap/opu/odata/sap/BC_EXT_APPJOB_MANAGEMENT;v=0002` |

## File Transfer

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_FileTransfer.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:FileTransfer:FTP` (implemented) | `HostName`: `FTPServer` |
| `ConnectionProfile:FileTransfer:SFTP` (implemented) | `HostName`: `SFTPServer` |
| `ConnectionProfile:FileTransfer:FTPS` | *(sample didn't parse cleanly)* |
| `ConnectionProfile:FileTransfer:AS2` | `PartnerDestinationUrl`: `sqa`<br>`HostName`: `sqa` |
| `ConnectionProfile:FileTransfer:Local` (implemented) | *none found* |
| `ConnectionProfile:FileTransfer:S3:Amazon` (implemented) | *none found* |
| `ConnectionProfile:FileTransfer:S3:Compatible` | `RestEndPoint`: `api.com` |
| `ConnectionProfile:FileTransfer:S3:AWSPrivateLink` | `RestEndPoint`: `apicom` |
| `ConnectionProfile:FileTransfer:Azure:SharedKey` | `AzureEndpoint`: `https://devAccount.blob.core.windows.net` |
| `ConnectionProfile:FileTransfer:Azure:ConnectionString` | `AzureEndpoint`: `` |
| `ConnectionProfile:FileTransfer:Azure:AdUserPass` | `AzureEndpoint`: `` |
| `ConnectionProfile:FileTransfer:Azure:AdClientSecret` | `AzureEndpoint`: `` |
| `ConnectionProfile:FileTransfer:Azure:AdCertificate` | `AzureEndpoint`: `` |
| `ConnectionProfile:FileTransfer:Azure:SharedAccessSignature` | `AzureEndpoint`: `` |
| `ConnectionProfile:FileTransfer:Azure:ManagedIdentity` | `AzureEndpoint`: `https://devAccount.blob.core.windows.net` |
| `ConnectionProfile:FileTransfer:SharePoint:AdUserPass` | `SharePointEndpoint`: `my.sharepoint.com` |
| `ConnectionProfile:FileTransfer:SharePoint:AdClientSecret` | `SharePointEndpoint`: `my.sharepoint.com` |
| `ConnectionProfile:FileTransfer:SharePoint:AdCertificate` | `SharePointEndpoint`: `my.sharepoint.com` |
| `ConnectionProfile:FileTransfer:SharePoint:ManagedIdentity` | `SharePointEndpoint`: `my.sharepoint.com` |
| `ConnectionProfile:FileTransfer:GCS` (implemented) | *none found* |
| `ConnectionProfile:FileTransfer:DualEndPoint` | `src_endpoint`: `<nested>`<br>`src_endpoint.HostName`: `localhost`<br>`dest_endpoint`: `<nested>`<br>`dest_endpoint.HostName`: `host2` |
| `ConnectionProfile:FileTransfer:Group` | *none found* |

## Infrastructure as Code

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_InfraCode.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Ansible AWX` | `Ansible URL`: `http://11.22.33.444:5678`<br>`Ansible URL API Path`: `http://11.22.33.444:5678/api/v2/` |
| `ConnectionProfile:AWS CloudFormation` | `CloudFormation URL`: `https://cloudformation.us-east-1.amazonaws.com` |
| `ConnectionProfile:Azure Resource Manager` | `Azure Base URL`: `https://management.azure.com`<br>`Azure Login URL`: `https://login.microsoftonline.com` |
| `ConnectionProfile:GCP Deployment Manager` | `Deployment Manager URL`: `https://www.googleapis.com/deploymentmanager/v2/projects/` |
| `ConnectionProfile:Terraform` | *none found* |

## Machine Learning

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_Machine.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:AWS Bedrock` | `Bedrock Agent Runtime URL`: `https://bedrock-agent-runtime.{{AWSRegion}}.amazonaws.com` |
| `ConnectionProfile:AWS Sagemaker` | `SageMaker URL`: `https://sagemaker.us-east-1.amazonaws.com` |
| `ConnectionProfile:Azure Machine Learning` | `Azure Login URL`: `https://login.microsoftonline.com`<br>`Azure ML  URL`: `https://{{location}}.api.azureml.ms/`<br>`Azure Management URL`: `https://management.azure.com/` |
| `ConnectionProfile:CrewAI` | `Crew URL`: `https://stock-broker-analyst-ae6f7cce-a150-4cf7-915-0bf13...` |
| `ConnectionProfile:GCP Vertex AI` | `GCP Vertex AI URL`: `https://{{location}}-aiplatform.googleapis.com` |
| `ConnectionProfile:LangGraph` | `LangSmith Deployment URL`: `https://api.host.langchain.com`<br>`LangSmith URL`: `https://api.smith.langchain.com` |
| `ConnectionProfile:OCI Data Science` | `OCI Instances URL`: `https://datascience.us-phoenix-1.oci.oraclecloud.com/2019...` |

## Mainframe Modernization

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_Mainframe.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:AWS Mainframe Modernization` | `Mainframe Modernization URL`: `https://m2.us-east-1.amazonaws.com`<br>`AWS Logs URL`: `https://logs.us-east-1.amazonaws.com` |
| `ConnectionProfile:Micro Focus Windows` | *(sample didn't parse cleanly)* |
| `ConnectionProfile:Micro Focus Linux` | *none found* |

## Messaging and Communication

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_Msg.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Atlassian Jira` | `Jira Data Center URL`: `http://10.10.10.10:8080` |
| `ConnectionProfile:Communication Suite` | `Microsoft Teams Webhook URL`: `https://default8d60578f78ef46ab8b66365b0465ec.26.environm...`<br>`Slack Webhook URL`: `https://hooks.slack.com/services/T017K8X36LE/B04ASJ247C7/...`<br>`Telegram URL`: `https://api.telegram.org/bot`<br>`WhatsApp URL`: `https://graph.facebook.com/Version/PhoneNumberID/messages` |
| `ConnectionProfile:DATADOG` | `Datadog URL`: `https://api.us5.datadoghq.com` |
| `ConnectionProfile:PagerDuty` | `Pager Duty URL`: `https://api.pagerduty.com` |

## Robotic Process Automation

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_RPA.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Automation Anywhere` | `Host`: `https://trial.cloud.automationanywhere.digital` |
| `ConnectionProfile:UI Path` | `Tenant Url`: `devabcdexample/DevDefault` |

## Web Services, Java, and Messaging

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_ConnectionProfiles_WebSrvc.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:WebServices` | *none found* |
| `ConnectionProfile:Web Services REST` | *none found* |
| `ConnectionProfile:Web Services SOAP` | *none found* |

## Messaging and Queuing

[Full parameter details](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/API_CodeRef_Connection_Profiles_PubSub.htm)

| Type | Endpoint field(s) |
| --- | --- |
| `ConnectionProfile:Apache Kafka` | `Kafka Cluster URL`: `<Cluster URL>`<br>`OAuth 2.0 Token Endpoint`: `<OAuth 2.0 REST Endpoint>` |
| `ConnectionProfile:AWS SNS` | `AWS SNS URL`: `https://sns.us-east-1.amazonaws.com` |
| `ConnectionProfile:AWS SQS` | `AWS SQS URL`: `https://sqs.us-east-1.amazonaws.com` |
| `ConnectionProfile:Azure Service Bus` | `Azure Login url`: `https://login.microsoftonline.com` |
| `ConnectionProfile:RabbitMQ` | `RabbitMQ URL`: `http://dba-server.bmc.com` |
