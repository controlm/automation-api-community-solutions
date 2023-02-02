# How to Integrate AWS Lambda with Control-M and BMC Helix Control-M<BR>



 ### To succesfully complete this integration, an AWS account is required. Access to a Control-M enviroment is also required and some Control-M knowledge is expected. Knowlegde of AWS services like [IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html), [EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html)  and AWS [lambda](https://aws.amazon.com/lambda/) is expected.  This integration can also be completed via the Control-M's Web Client.<br><br> 
## In five steps, this exercise will walk you through setting up and executing an AWS lambda job in Control-M
1. Create the Lambda function in AWS
1. Install the Control-M Automation CLI
2. Deploy a Connection Profile 
3. Define and run your Control-M Job 
5. Monitor the job in the Control-M GUI
<br>
<br>

## Getting Started <br> <br>


### Step 1 -  ``Create a Lambda function in AWS`` <br>  
Follow this  [link](https://docs.aws.amazon.com/lambda/latest/dg/getting-started.html) to get started with Lambda and create your first function

### Step 2 -  ``Install the Control-M Automation CLI`` <br>  

The Control-M Automation CLI allows you to automate and work interactively with Control-M. Follow this [link](https://docs.bmc.com/docs/automation-api/monthly/installation-993192247.html) to install the Control-M CLI. <br> <br>
### Step 3 - ``Deploy a Connection Profile`` 
-   Create a json file and name it ***`ctm-lambda-connection-profile.json`***

-   Copy the codes in [ctm-lambda-connection-profile.json](./ctm-lambda-connection-profile.json) to the json file you created 
<br>
<br>
``` json
{
    "AWS_CONNECTION": {
      "Type": "ConnectionProfile:AWS",
      "TargetAgent": "AgentHost",
      "TargetCTM": "CTMHost",
      "AccessKey": "1234",
      "SecretAccessKey": "mysecret",
      "Region": "ap-northeast-1"
    }
  }

```
## The Following parameters should be specified

\*  `TargetAgent`: The Control-M/Agent to which the connection profile will be deployed. 

\*  `TargetCTM`: The Control-M/Server to which the connection profile will be deployed. If there is only one Control-M/Server, that is the default

\*  `AccessKey`: AWS account Access Key.

\*  `SecretAccessKey`: AWS account Secret Access Key. Use [`Secrets in code`](https://docs.bmc.com/docs/automation-api/monthly/secrets-in-code-993192286.html) to avoid exposing your AWS Secret Access Key in code. 

\* `Region`: Location of the AWS user. 

\* `Save and Deploy the Connection profile by running the command below` 
<br>

``` json
ctm deploy ctm-lambda-connection-profile.json


```

<br>


### Step 4 - ```Define the Control-M job```
### Here is a JSON example of a Lambda job definition in Control-M. <br> <br> 
``` json
{
    "AwsLambdaJob": {
    "Type": "Job:AWS:Lambda",
    "ConnectionProfile": "AWS_CONNECTION",
    "FunctionName": "LambdaFunction",
    "Version": "1",
    "Payload" : "{\"myVar\" :\"value1\" \\n\"myOtherVar\" : \"value2\"}",
    "AppendLog": true }

}
```
## Specify the following parameters: <br> 

\*  `ConnectionProfile`: Use the connection profile deployed in the previous step. 

\*  `FunctionName`: The AWS Lambda function to execute

\* `Version` : The version of the Lambda function. The default is $Latest

\*  `Paylaod`: (Optional) The Lambda function payload, in JSON.

\*  `AppendLog` : Whether to add the log to the job’s output, either true (the default) or false. 

<br>

I will be adding these three Lambda jobs to an existing Control-M workflow which can be found in  [this](./ctm-lambda-job.json) file.

``` json
{
"Check-Inventory-Lambda-Job": {
    "Type":"Job:AWS:Lambda",
    "Application":"mol-app",
    "ConnectionProfile": "MOL-AWS",
    "FunctionName": "online-store-checkout-workflow-dev-checkInventory",
    "AppendLog" : true
},
"Calculate-Total-Lambda-Job": {
    "Type":"Job:AWS:Lambda",
    "Application":"mol-app",
    "ConnectionProfile": "MOL-AWS",
    "FunctionName": "online-store-checkout-workflow-dev-calculateTotal",
    "AppendLog" : true

},
"Process-payment-Total-Lambda-Job": {
    "Type":"Job:AWS:Lambda",
    "Application":"mol-app",
    "ConnectionProfile": "MOL-AWS",
    "FunctionName": "online-store-checkout-workflow-dev-StartPaymentProcess",
    "AppendLog" : true }
}
```

- Create a file and name it     ***`ctm-lambda-job.json`***
- Copy the codes in [ctm-lambda-job.json](./ctm-lambda-job.json) to the json file you just created.
- Edit the parameters to match your own job definitions.
- Save the json file and run the command below <br>

```
ctm run ctm-lambda-job.json
```
- You should receive an output with the ***run Id***

- Check the status of the job by running the command below 
```
ctm run status <run Id>

```

### Step 5 - ``Monitor the job in  Control-M GUI``

In the Control-M (or BMC Helix Control-M) GUI, you can view the status of your job, review logs and outputs, perform critical user tasks, and resolve various issues. 
<br>
<br>
<img src="images/Capture.png" width = "1800">

