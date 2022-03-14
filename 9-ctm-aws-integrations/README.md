# Steps for setting up and running an AWS Glue job in Control-M

<br>


All code artifacts for this demo can found in this repository. To succesfully complete this tutorial, some knowledge of Control-M is required. Knowlegde of AWS services like [IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html), [EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html)  and AWS [Glue](https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html) is also required. Make sure you have the Control-M for Glue [plug-in](https://docs.bmc.com/docs/automation-api/monthly/deploy-service-1064010746.html#Deployservice-jobtype_deploy) installed in your Control-M enviroment.  If you are new to AWS Glue, follow this [link](https://aws.amazon.com/glue/?whats-new-cards.sort-by=item.additionalFields.postDateTime&whats-new-cards.sort-order=desc) to learn more about AWS Glue Job. <br><br>
## In five steps, this exercise will walk you through setting up and  running an AWS Glue job in Control-M
1. Install the Control-M Automation CLI
2. Deploy a Connection Profile 
3. Define The Glue Job 
4. Run The Glue Job
5. Monitor the Glue job in Helix Control-M SaaS GUI
<br>
<br>
### Step 1 -  ``Install the Control-M Automation CLI`` <br>  

The Control-M Automation CLI allows you to automate and work interactively with Control-M which enables you to automate your jobs in  Control-M. Follow this [link](https://docs.bmc.com/docs/automation-api/monthly/installation-1064010696.html) to install the Control-M Automation CLI.   

<br> <br>
### Step 2 - ``Deploy a Connection Profile`` 
-   Create a json file and name it ***`glue-connection-profile.json`***

-   Copy the codes in [glue-connection-profile.json](./glue-connection-profile.json) to the json file you created 
<br>
<br>
``` json
{
    "GLUECONNECTIONIAM": {
      "Type": "ConnectionProfile:AWS Glue",
      "AI-IAM Role": "GLUEEC2IAMROLE",
      "AI-Authentication": "NOSECRET",
      "AI-AWS_REGION": "eu-west-2",
      "AI-Glue url": "glue.eu-west-2.amazonaws.com",
      "AI-Connection Timeout": "40",
      "Description": "",
      "Centralized": true
    }
  }

```


\*  Change `AI-IAM Role` to the name of the already created IAM role in AWS 

\*  Make sure `AI-Authentication` is set to "NOSECRET" 

\*  Change the `AI-AWS_REGION` to the AWS region you have your Glue job defined

\*  Add a `Description` to the connection profile (optional)

\* Save and Deploy the Connection profile by running the command below 
<br>

``` json
ctm deploy glue-connection-profile.json


```
<br>
You should receive a returned payload like the image shown below :<br>
<br>
<img src="images/Connection Profile Deploy.png" width = "800">

<br>
<br>


### Step 3 - ```Define the Glue Job```
Now that our connection profile is deployed. Let us define our Glue job. To run an AWS Glue job with Control-M , you must already have your job defined in your AWS enviroment. In reality, the Glue job would be part of a large ETL pipeline. 

- Create a file and name it     ***`ctm-glue-job.json`***
- Copy the codes in [ctm-glue-job.json](./ctm-glue-job.json) to the json file you just created. This glue job is a part of different command jobs workflow. 
```json
{
  "mol-glue-demo-folder" : {
    "Type" : "Folder",
    "ControlmServer" : "smprod",
    "OrderMethod" : "Manual",
    "ActiveRetentionPolicy" : "CleanEndedOK",
    "CreatedBy" : "moladugb",
    "Application" : "mol-app",
    
    
      "glue-job" : {
          "Type" : "Job:AWS Glue",
          "ConnectionProfile" : "MOL-GLUE-CONNECTION-PROFILE",
          "Glue Job Name" : "mol-glue-job-run",
          "Glue Job Arguments" : "unchecked",
          "CreatedBy" : "moladugb",
          "Host" :"glueagents",
          "Application" : "mol-app"
  },
      "command-job-1" : {
          "Type" :"Job:Command",
          "Command" : "echo Hello World!",
          "RunAs" : "ctmagent",
          "Host" : "glueagents",
          "Application" :"mol-app"
          
      
  },
      "command-job-2" : {
          "Type" :"Job:Command",
          "Command" : "echo Hello World!",
          "RunAs" : "ctmagent",
          "Host" : "glueagents",
          "Application":"mol-app"
    
  },
      "command-job-3" : {
          "Type" :"Job:Command",
          "Command" : "echo I am out",
          "RunAs" : "ctmagent",
          "Host" : "glueagents",
          "Application":"mol-app"
    
  },
  
      "command-job-4" : {
          "Type" :"Job:Command",
          "Command" : "echo Bye now",
          "RunAs" : "ctmagent",
          "Host" : "glueagents",
          "Application":"mol-app"
  },
      "Flow1" : {
          "Type": "Flow",
          "Sequence" : ["command-job-1","glue-job" ]
      },
      "Flow2" : {
          "Type": "Flow",
          "Sequence" : ["glue-job", "command-job-2"]
      },
      "Flow3" : {
          "Type": "Flow",
          "Sequence" : ["glue-job", "command-job-3"]
      
      },
      "Flow4" : {
          "Type":"Flow",
          "Sequence" :["glue-job","command-job-4"]
      }
  }
}

```

\* Fill in the appropriate objects like the Control-M Sever, Application, Host and Connection Profile that was deplopyed earlier <br> <br>
### Step 4 - ``Run The Glue Job`` 

<br>

Save the json file and run the command below <br>

```
ctm run ctm-glue-job.json
```
- You should receive an output with the ***run Id***

- Check the status of the job by running the command below 
```
ctm run status <run Id>

```
- If succesfull, you should receive a payload like the image below <br> <br>

<img src="images/Capture.png" width = "800">

<br>
<br>

### Step 5 - ``Monitor the Glue job in the Helix Control-M SaaS GUI``

You can also monitor your job in the SaaS GUI by using the viewpoints in the monitoring domain. The monitoring domain enables the users to monitor the processing of jobs. In this domain , you can perfrom critical user tasks and handle problems. 
<br>
<br>
<img src="images/monitoring domain.png">