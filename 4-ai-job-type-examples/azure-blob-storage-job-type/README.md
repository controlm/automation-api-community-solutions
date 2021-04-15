# Azure blob storage
Azure Blob storage is the storage service for unstructured data. This job type supports file transfer and management capabilities. The operations that are available are:

* Download: Downloads a blob into a local file
* Upload: Uploads a file into a container
* List: List all blobs (files) in a container
* Copy: Copies a blob from one container into another
* Delete: Deletes a blob
* Create container: Creates a container
* Delete container: Deletes a container including any blobs inside the container.

## Prerequisites and installation notes:

This job type has the following prerequisites:

* Control-M Agent with the Application Integrator CM
* Azure CLI v2.0 installed
* Azure CLI authenticated with the �az login� command

__Note:__ This job types supports multi-factor authentication by using Azure's az login command as prerequisites. This job type can be modified to include the azure authentication parameters as part of the connection profile in scenarios where a 2 factor authentication is used. This would eliminate the prerequisites to authenticate the Azure CLI.

Download the Application Integrator job from the [Application Integrator Hub](https://communities.bmc.com/docs/DOC-106716)

### Installation steps:

* Install the Azure CLI on the agent where you want to run the jobs on.
* Authenticate the CLI using az login
* Deploy the job type to the agent. Make sure the Application Integrator is installed on that agent.
* Configure a connection profile. You can create and receive the storage account details trough the Azure portal.
* Create your first job

### Compatibility:

* Application version: This job type is tested against Azure CLI v2.0
* Platforms: This job type follows the Azure CLI compatibility and was tested on both Linux and Windows.
* Control-M version: Tested on Control V9 and V9.0.18
* Application Integrator version: Tested with Application Integrator 8 and 9
* Job type: V2 of the application integrator job type (updated in December 2018)

## Connection profile

Before we can run any job, we need to create a connection profile. Below an example of a connection profile:
```
{
  "<CONNECTION_PROFILE NAME>" : {
    "Type" : "ConnectionProfile:ApplicationIntegrator:Azure blob storage",
    "AI-Account name" : "<AZURE STORAGE ACCOUNT NAME>",
    "AI-Account key" : "<AZURE STORAGE ACCOUNT KEY>",
    "TargetAgent" : "<HOST WHERE THE AZURE CLI IS INSTALLED ON",
    "TargetCTM" : "<CONTROL-M SERVER>"
  }
}
```
See file [1_azure_blob_connection_profile.json](1_azure_blob_connection_profile.json) for an example connection profile definition.

__Note:__ Remember to authenticate the agent for the ___run as user___ in case of multi-factor (default) authentication by using Azure's az login command as prerequisites. See Prerequisites and installation notes above.

## Code reference

This job type is using specific attributes depending on the action (list, download, upload, copy, delete, create container).

The job type is Job:ApplicationIntegrator:Azure blob storage and can be specified as:
```
 "Type" : "Job:ApplicationIntegrator:Azure blob storage",
```
For each action, the following attributes are applicable:
```
  "ConnectionProfile" : "<CONNECTION_PROFILE NAME>",
      	
  "AI-Action" : "<Upload|Download|List|Copy|Delete|Create container>",
  "AI-Output" : "json|jsonc|table|tsv",
  "AI-Additional parameters" : "<OPTIONAL PARAMETERS>",
```

Attribute|Possible values|Comment
---------|---------------|-------
AI-Action|Upload, Download, List, Copy, Delete or Create container|__Mandatory.__ Specifies the action to be performed.
AI-Output|json, jsonc, table or tsv|___Optional.___ Specifies the output format. If empty, the default will be used (json)
AI-Additional parameters|See Azure CLI documentation|___Optional.___ Add specific parameters to the Azure CLI command in case your use case requires this

### Create container action

The action Create container will create a new container. We set the AI-Action to "Create container" and in addition to the generic job attributes, we need to specify the container name and the Public Access attirbute:
```
  "AI-Action" : "Create container",
  "AI-Container (Create/Delete)" : "<AZURE BLOB CONTAINER NAME>",
  "AI-Public Access" : "Blob|Container|Off"
```
The Public Access parameter is controlling the level of public access. It can contain Blob, Container or Off. If left empty, it is set to the defailt value Off. Please see the Azure CLI documentation for more details

See file [2_create_a_azure_blob_container.json](2_create_a_azure_blob_container.json) for an example job definition for a job using the Create container action.

### Upload / Download action

The action Upload will let you upload a blob into a container. Download will download a blob from a container to a local file on the agent. Both actions are using the same parameters.
```
  "AI-Action" : "Upload|Download",
  "AI-Container (Up/Download)" : "<AZURE BLOB CONTAINER NAME>",
  "AI-Blob name (Up/Download)" : "<BLOB_NAME>",
  "AI-File path" : "<PATH TO FILE ON AGENT FILE SYSTEM>"
```
See files [3_upload_file_into_container.json](3_upload_file_into_container.json) and [4_download_blob_to_local_file.json](4_download_blob_to_local_file.json) for an example job definition for a job using the Upload and Download action.

### List action

This action will list all blobs in a specific container. We set the AI-Action to "List" and in addition to the generic job attributes, we need to specify the container name:
```
  "AI-Action" : "List",
  "AI-Container (List)" : "<AZURE BLOB CONTAINER NAME>"
```
See file [5_list_files_in_container.json](5_list_files_in_container.json) for an example job definition for a job using the List action.

### Copy action

The action Copy will copy a blob to another container. We set the AI-Action to "Copy" and in addition to the generic job attributes, we need to specify the source and destination blob and container:
```
  "AI-Action" : "Copy",
  "AI-Source-uri" : "<SOURCE-URI OF BLOB TO BE COPIED",
  "AI-Destination container" : "<DESTINATION AZURE BLOB CONTAINER NAME>",
  "AI-Destination blob name" : "<DESTINATION AZURE BLOB NAME>"
```
See file [6_copy_blob_to_another_container.json](6_copy_blob_to_another_container.json) for an example job definition for a job using the Copy action.

### Delete action

The action Delete will remove a blob from a container. We set the AI-Action to "Delete" and in addition to the generic job attributes, we need to specify the blob and container name:
```
  "AI-Action" : "Delete",
  "AI-Container (Delete)" : "<AZURE BLOB CONTAINER NAME>",
  "AI-Blob name (Delete)" : "<BLOB_NAME>"
```

See file [7_delete_blob_from_container.json](7_delete_blob_from_container.json) for an example job definition for a job using the Delete action. 

### Delete container action

The action Delete container will remove a container __including any blobs inside the container___. We set the AI-Action to "Delete container" and in addition to the generic job attributes, we need to specify the container name:
```
  "AI-Action" : "Delete container",
  "AI-Container (Create/Delete)" : "<AZURE BLOB CONTAINER NAME>",
```

See file [8_delete_container.json](8_delete_container.json) for an example job definition for a job using the Delete Container action.
