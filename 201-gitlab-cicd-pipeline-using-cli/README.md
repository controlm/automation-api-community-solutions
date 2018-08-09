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

The [sample.json](sample.json) file holds a job flow purely to demonstrate the CI/CD integration. In real life, this would be the workflow definition that is being updated as part of a project.
The flow grabs data from 3 different sources. These data sources are merged into one file and printed. In addition there is a job that is intended to fail because the command does not exist. The job DoSometingElse is doing a sleep for 2 minutes to demonstrate the graphical monitoring capabilities of the Workbench.

This sample will run without any modification in a Control-M workbench. 

## DeployDescriptorStaging.json
The [DeployDescriptorStaging.json](DeployDescriptorStaging.json) file updates the specific attributes of the sample.json to match the staging environment. This file is used during the deployment of the sample.json file to the staging environment.

You will need to replace the following strings with a value that are applicable for the staging environment
* __<RUN_AS_USER>:__ Sets the Run As user name
* __\<HOST>:__ Sets the host name of the agent where the jobs defined in the sample.json file needs to be executed on
* __<WORKING_DIR>:__ Set the working dir for the  jobs defined in the sample.json file. Best is to do a find and replace since this value is used multiple times.

## DeployDescriptorMaster.json
The [DeployDescriptorMaster.json](DeployDescriptorMaster.json)  file updates the specific attributes of the sample.json to match the production environment. This file is used during the deployment of the sample.json file to the staging environment.

You will need to replace the following strings with a value that are applicable for the production environment
* __<RUN_AS_USER>:__ Sets the Run As user name
* __\<HOST>:__ Sets the host name of the agent where the jobs defined in the sample.json file needs to be executed on
* __<WORKING_DIR>:__ Set the working dir for the  jobs defined in the sample.json file. Best is to do a find and replace since this value is used multiple times.

## .gitlab-ci.yml
The	[.gitlab-ci.yml](.gitlab-ci.yml) file specifies the Gitlab pipeline.

First, we specify the different stages of the pipeline. This helps to track the progress of a pipeline. 

```
stages:
  - prep
  - build
  - test
  - deploy
```

### prep stage
The prep stages prepares sets the correct pre-conditions for the pipeline. In this example, we add the environment to the Automation-API CLI. We use the ```only:``` attribute to specify this action for the staging branch en master branch (production). The ```allow_failure: true``` attribute is used to ignore any failure in this step. This is done to suppress an error that the environment already exists. 

```
  stage: prep
  allow_failure: true
  script:
      - ctm env add staging "$STAGING_ENDPOINT" $STAGING_USER $STAGING_PASSWORD
  only:
    - staging
  tags:
    - ctm
    
1.1 Configure production environment:
  stage: prep
  allow_failure: true
  script:
      - ctm env add production "$PRODUCTION_ENDPOINT" $PRODUCTION_USER $PRODUCTION_PASSWORD
  only:
    - master
  tags:
    - ctm
```

### build stage
The build stage validates if the json format is correct. We use the ```only:``` attribute again to execute this step for each environment. The ```-e``` attribute is used to specify the environment in the Automation API CLI, 


```
2.1 Build json files for staging:
  stage: build
  script:
    - ctm build sample.json DeployDescriptorStaging.json -e staging
  only:
    - staging
  tags:
    - ctm

2.1 Build json files for master:
  stage: build
  script:
    - ctm build sample.json DeployDescriptorMaster.json -e production
  only:
    - master
  tags:
    - ctm
```

Note that we use the deploy descriptor file to update the sample.json with environment specific:

```ctm build sample.json DeployDescriptorStaging.json -e staging```

### test stage
The test stage is used to run the actual job and "validate" the output. The first job prints the transformation using the ```ctm deploy transform``` service with the deploy descriptor file. This job is purely for debugging issues. It will show the json that will actually get deployed. Printing the transformed job will help debugging any errors found in the test stage.

```
3.1 Print Transformation for staging:
  stage: test
  script:
    - ctm deploy transform sample.json DeployDescriptorStaging.json -e staging
  only:
    - staging
  tags:
    - ctm
    
3.1 Print Transformation for master:
  stage: test
  script:
    - ctm deploy transform sample.json DeployDescriptorMaster.json -e production
  only:
    - master
  tags:
    - ctm
```

The next job will actually run the jobs on either the staging or production environment.

___Note: You should always validate if the jobs can be executed in a real production environment___
```
3.2 Run json files on staging:
  stage: test
  script:
    - ctm run sample.json DeployDescriptorStaging.json -e staging
  only:
    - staging
  tags:
    - ctm
    
3.2 Run json files on master:
  stage: test
  script:
    - ctm run sample.json DeployDescriptorMaster.json -e production
  only:
    - master
  tags:
    - ctm
```
Note that we use the deploy descriptor file to update the sample.json with environment specific:

```ctm run sample.json DeployDescriptorStaging.json -e staging```

The next job validates the result of the previous step. In this example, we just print "All good". In real life, you would probably call a test automation solution in this step or build a custom script that validates the output.

```
3.3 Check result:
  stage: test
  script:
    - echo 'All good'
  tags:
    - ctm
```

### deploy stage
We can now actually deploy the jobs on the staging or production environment once all previous steps are successful:

```
4.1 Deploy jobs for staging:
  stage: deploy
  script:
    - ctm deploy sample.json DeployDescriptorStaging.json -e staging
  only:
    - staging
  tags:
    - ctm
    
4.1 Deploy jobs for master:
  stage: deploy
  script:
    - ctm deploy sample.json DeployDescriptorMaster.json -e production
  only:
    - master
  tags:
    - ctm
```
    
Note that we use the deploy descriptor file to update the sample.json with environment specific:

```ctm deploy sample.json DeployDescriptorStaging.json -e staging```
