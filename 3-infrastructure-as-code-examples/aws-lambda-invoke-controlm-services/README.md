# Handle AWS Events as triggers for Control-M Actions

This is an implementation of AWS SQS messages triggering a Lambda function that in turn invokes Control-M services. The current version processes SQS messages with the specific format described in the SQSMessages.txt file below.

This example consists of the following:
* __ctmEventHandler.py:__ Python code for the Lambda function
* __SQSMessages.txt:__ SQ message text and format that is consumed by the Lambda function
* __JGO_Std.template:__ JSON job definitions that serve as a template. These reside in an S3 bucket and can contain variables 

To install the example:
1. Define an SQS queue named __ctmrequests__.
2. Define a role with access to Amazon SQS, Amazon S3 and Amazon Secrets Manager
3. Define Control-M environments in Amazon Secrets Manager. Each Environment should have the following attributes:
   - The Secret name should be CTMEnvironment_"environment name". The "environment name" is specified as an attribute in the SQS message
   - Each Secret should contain four key/value pairs as follows. 
     - __endpoint__ contains the Control-M endpoint in the format https://hostname:port/automation-api
	 - __username__ contains the user name
	 - __password__ contains the password
	 - __bucket__ contains the S3 bucket where templates for this environment as stored
2. Define the ctmEventHandler Lambda Function with a Python 3.6 runtime
3. Upload the Pythom code below
4. Select SQS as the event trigger and select the ctmrequests queue

This is a work in progress with additional details for implementation to follow as well as support for SNS and S3 events.