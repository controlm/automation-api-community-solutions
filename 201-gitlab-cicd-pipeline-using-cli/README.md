# Integrate Control-M with Gitlab CI/CD pipeline

This example shows how to include Control-M to a CI/CD pipeline using the Automation API CLI.

This example consists of the following:
* __sample.json:__ Sample file holding job definitions
* __DeployDescriptorStaging.json:__ DeployDescriptor file which updates the sample.json with environment specific values for the staging environment
* __DeployDescriptorMaster.json:__ DeployDescriptor file which updates the sample.json with environment specific values for the production environment
* __.gitlab-ci.yml:__ Gitlab yml file that describes the jobs in the pipeline.

To install the example, you can:
1. Clone this repository in a Gitlab repository
2. Make sure the Gitlab runner has the Automation API installed.
3. Set the variables in Gitlab (see "Gitlab variables" below)
4. Replace <RUN_AS_USER>, \<HOST> and <WORKING_DIR> strings in the deploy descriptor files for the correct values. (See DeployDescriptorStaging.json and DeployDescriptorMaster.json below)

## Gitlab variables:

In order to use this example, you would need to set the following variables in the Gitlab pipeline:
* __STAGING_ENDPOINT:__ This variable should hold the Automation API endpoint for the staging environment. The format would be https://<hostname>:8443:/automation-api
* __STAGING_USER:__ The name of the Control-M user which will be used to deploy the changes on the staging 
* __STAGING_PASSWORD:__ The password of the Control-M user.

For the production environment, similar variables need to be defined:
* __PRODUCTION_ENDPOINT__
* __PRODUCTION_USER__
* __PRODUCTION_PASSWORD__

## sample.json

This file holds a job flow purely to demonstrate the CI/CD integration. In real life, this would be the workflow definition that is being updated as part of a project.
The flow grabs data from 3 different sources. These data sources are merged into one file and printed. In addition there is a job that is intended to fail because the command does not exist. The job DoSometingElse is doing a sleep for 2 minutes to demonstrate the graphical monitoring capabilities of the Workbench.

This sample will run without any modification in a Control-M workbench. 

## DeployDescriptorStaging.json
This file updates the specific attributes of the sample.json to match the staging environment. This file is used during the deployment of the sample.json file to the staging environment.

You will need to replace the following strings with a value that are applicable for the staging environment
* __<RUN_AS_USER>:__ Sets the Run As user name
* __\<HOST>:__ Sets the host name of the agent where the jobs defined in the sample.json file needs to be executed on
* __<WORKING_DIR>:__ Set the working dir for the  jobs defined in the sample.json file. Best is to do a find and replace since this value is used multiple times.

## DeployDescriptorMaster.json
This file updates the specific attributes of the sample.json to match the production environment. This file is used during the deployment of the sample.json file to the staging environment.

You will need to replace the following strings with a value that are applicable for the production environment
* __<RUN_AS_USER>:__ Sets the Run As user name
* __\<HOST>:__ Sets the host name of the agent where the jobs defined in the sample.json file needs to be executed on
* __<WORKING_DIR>:__ Set the working dir for the  jobs defined in the sample.json file. Best is to do a find and replace since this value is used multiple times.
