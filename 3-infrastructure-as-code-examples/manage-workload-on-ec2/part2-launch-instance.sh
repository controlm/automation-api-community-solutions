#!/bin/bash

#   Check the newly created AMI is available
aws ec2 describe-images --region us-west-2 --image-ids ami-08c703f67c7b7f793 --query 'Images[0].State' --output text

#   Launch ec2 instance(s) 
aws ec2 run-instances --image-id ami-08c703f67c7b7f793 --count 1 --region us-west-2 --instance-type t2.micro --key-name JoGoKey --security-group-ids sg-0125e6ff1d318ef2a --iam-instance-profile Name=jogoldbeAdmin4EC2 --tag-specifications 'ResourceType=instance,Tags=[{Key=ctmenvironment,Value=ctmprod},{Key=ctmserver,Value=smprod},{Key=ctmhostgroup,Value=awsec2group},{Key=Name,Value=ctmprod Control-M Agent}]'

aws