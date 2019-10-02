# S3 Compatible Storage
This example uses Ceph S3 Compatible object storage (running in Kubernetes with the rook operator. For more information on this see the Rook docs [here](https://rook.io/docs/rook/v1.0/ceph-object.html))  

Configuring Kubernetes, Rook, and Ceph are out of the scope of this example.

### Create Automation API secrets
The AccessKey, SecretKey, and RestEndpoint must be retrieved, the specific method this is done will likely varify from environment to environment. If using a Kubernetes Rook based Ceph Object Store the values can be retrieved with the following commands:  

```shell
UserName=demo-user
StoreName=demo-store
AccessKey=$(kubectl get secret/rook-ceph-object-user-$StoreName-$UserName -n rook-ceph -o jsonpath='{ .data.AccessKey }' | base64 -d)
SecretKey=$(kubectl get secret/rook-ceph-object-user-$StoreName-$UserName -n rook-ceph -o jsonpath='{ .data.SecretKey }' | base64 -d)
endpoint=http://$(kubectl get service/rook-ceph-rgw-$StoreName-lb -n rook-ceph -o jsonpath='{ .status.loadBalancer.ingress[*].ip }'):$( kubectl get service/rook-ceph-rgw-$StoreName-lb -n rook-ceph -o jsonpath='{ .spec.ports[*].port }')
```

If awscli is installed, the credentials can be validated by running the following aws cli commands (where "demobucket" is the name of the desired bucket):  

```shell
aws configure --profile=DEMO set aws_access_key_id $AccessKey
aws configure --profile=DEMO set aws_secret_access_key $SecretKey
aws --endpoint=$endpoint --profile=DEMO s3 ls s3://demobucket
```

Store the Secret Key in an Automation API secret using the following command:

```shell
ctm config secret::add CephDemoSecretKey $SecretKey
```

For more information on Automation API Secrets see the online documentation [here](https://docs.bmc.com/docs/display/workloadautomation/API+Code+Reference+-+Secrets+in+Code)

### Define Connection Profiles
The S3 Compatible MFT Connection Profile will use the secrets created in the previous section.
```json
"CephDemoS3Compat": {
    "Type": "ConnectionProfile:FileTransfer:S3:Compatible",
    "RestEndPoint": "http://CephDemoEndpoint:80",
    "AccessKey": "CephDemoAccessKey",
    "SecretAccessKey": {"Secret": "CephDemoSecretKey"},
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
| ConnectionProfileDest  | Sets the destination for files to be transfered to  | CephDemoS3Compat  |
| Host  | The Control-M/Agent where the File Transfer job will run  | demoagent  |
| S3BucketName  | The S3 Bucket to copy files from/to  | demobucket  |
| FileTransfers  | An array of json objects representing the files to be transfered  | -  |

Example job:
```json
"TransferFromLocalToS3CompatableStorage" :
{
  "Type" : "Job:FileTransfer",
  "Application" : "aft",
  "SubApplication": "s3compatable",
  "ConnectionProfileSrc" : "LocalConn",
  "ConnectionProfileDest" : "CephDemoS3Compat",
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
The full example JSON definition (including both connection profiles and the file transfer job) is available [here](./mft-s3-compat.json)
