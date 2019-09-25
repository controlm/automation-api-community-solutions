## Requirement

For an ongoing project, a developer has been given the task to define a job that must run at the end of a series of transactions to upload a generated file to Amazon S3 storage, or S3 compatible storage. The job will be triggered by their application which can interact with REST services, so it can call the Automation API /run service to start the job in Control-M.

## Prerequisites:
* Control-M Managed File Transfer 9.0.19 or higher
* Control-M Automation API 9.0.19.110 or higher
* Access key + Secret Key for login and access to the required bucket on Amazon S3 or S3 Compatible storage

## Steps
* Define Automation API Secrets that contain the Access Key and Secret Key
* Define connection profiles S3 + Local
* Define File Transfer Job

## Table of Contents
* [Amazon S3 Storage](./aws-s3-storage)
* [S3 Compatible Storage](./s3-compatible-storage)
