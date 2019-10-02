# AWS S3 Storage
This example used Amazon AWS S3. Configuring AWS AMI Users/Policies/Security Groups and S3 Buckets is out of the scope of this example.

### Create Automation API secrets
Retrieve AWS Access Key and Secret key from the AWS console or from your IAM administrator, then store the Secret Key in an Automation API secret using the following command: (provided the relevant value and press enter)
```shell
ctm config secret::add AwsDemoSecretKey -p
```

These secrets will be used in the JSON format connection profile instead of storing the API Keys in plaintext.

For more information on Automation API Secrets see the online documentation [here](https://docs.bmc.com/docs/display/workloadautomation/API+Code+Reference+-+Secrets+in+Code)

### Define Connection Profiles
The AWS S3 MFT Connection Profile will use the secrets created in the previous section.
```json
"AwsDemoS3": {
    "Type": "ConnectionProfile:FileTransfer:S3:Amazon",
    "Region": "us-east-1",
    "AccessKey": "demo-access-key",
    "SecretAccessKey": {"Secret": "AwsDemoSecretKey"},
    ...
}
```

A Local FileTransfer connection profile must also be defined. To avoid entering the password used in this profile in the JSON file in plaintext, create another secret to store the password used for the local connection profile:

```shell
ctm config secret::add LocalControlMPasswd -p
```

Using the `-p` option will prompt the user for the value to store in the secret so that the password is not stored in the shell history.

Once the LocalControlMPasswd secret is created, the Local Connection Profile can be defined like:
```json
"LocalConn" : {
 "Type" : "ConnectionProfile:FileTransfer:Local",
 "TargetAgent" : "demoagent",
 "User" : "controlm",
 "Password" : {"Secret": "LocalControlMPasswd"}
}
```

Notes:
* The value for `TargetAgent` should be updated to be an agent host with Control-M Managed File Transfer 9.0.19 or higher deployed
* If more than one Control-M/Server is defined on the Control-M/Enterprise Manager, the key `TargetCTM` must be added with the value of the Control-M/Server Name that has the previously mentioned Control-M/Agent defined.
* The `ConnectionProfile:FileTransfer:Local` type has an optional parameter of `OsType`, if not set the default is `Unix`. If the specified Control-M/Agent is Windows, add the `OsType` key with a value of `Windows`

For more information on defining connection profiles in JSON with Automation API see the online documentation [here](https://docs.bmc.com/docs/display/workloadautomation/API+Code+Reference+-+Connection+Profiles)

### Define File Transfer Job
Now that the connection profiles have been defined, a file transfer job can be created that makes use of the connection profiles.
##### Important values:
| Key  | Usage  | Example Value  |
| :------------: | :------------: | :------------: |
| ConnectionProfileSrc  | Sets the source for files to be transfered from  | LocalConn  |
| ConnectionProfileDest  | Sets the destination for files to be transfered to  | AwsDemoS3  |
| Host  | The Control-M/Agent where the File Transfer job will run  | demoagent  |
| S3BucketName  | The S3 Bucket to copy files from/to  | demobucket  |
| FileTransfers  | An array of json objects representing the files to be transfered  | -  |

Example job:
```json
"TransferFromLocalToAwsS3" :
{
  "Type" : "Job:FileTransfer",
  "Application" : "aft",
  "SubApplication": "s3aws",
  "ConnectionProfileSrc" : "LocalConn",
  "ConnectionProfileDest" : "AwsDemoS3",
  "Host": "demoagent",
  "S3BucketName": "demobucket",
  "FileTransfers" :
  [
    {
      "Src" : "C:\\demo\\data.csv",
      "Dest" : "s3://demobucket/"
    }
  ]
}
```
The full example JSON definition (including both connection profiles and the file transfer job) is available [here](./mft-s3-aws.json)

For more information about defining File Transfer jobs in JSON with Automation API see the online documentation [here](https://docs.bmc.com/docs/display/workloadautomation/API+Code+Reference+-+Job+types#Jobtypes-JobFileTransferJob:FileTransfer)
