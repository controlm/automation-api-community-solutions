# Integrate Control-M with Gitlab CI/CD pipeline

This example shows how to include Control-M to a CI/CD pipeline using the Automation API CLI.

This example consists of the following:
* __sample.json:__ Sample file holding job definitions
* __DeployDescriptorStaging.json:__ DeployDescriptor file which updates the sample.json with environment specific values for the staging environment
* __DeployDescriptorMaster.json:__ DeployDescriptor file which updates the sample.json with environment specific values for the production environment
* __.gitlab-ci.yml:__ Gitlab yml file that describes the jobs in the pipeline.

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
The flow grabs data from 3 different sources. These data sources are merged into one file and printed. In addition there is a job that fails bevause the command does not exist.

## __DeployDescriptorStaging.json
