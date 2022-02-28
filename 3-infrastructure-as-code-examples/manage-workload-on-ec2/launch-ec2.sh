#!/bin/bash

#   arg1    environment name
#   arg2    number of instances to launch
#
CTM_ENV=$1
CTM_HGRP=$2
inum=$3

AWS_Region=`curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -f 2 -d ':' | sed s/[^a-zA-Z0-9_-]//g`

envserver=${CTM_ENV}-server
ctmserver=`aws secretsmanager get-secret-value --region ${AWS_Region} --secret-id ${envserver} --query 'SecretString' --output text`

aws ec2 run-instances --image-id ami-08c703f67c7b7f793 --count 1 --region ${AWS_Region} --instance-type t2.micro --key-name JoGoKey --security-group-ids sg-0125e6ff1d318ef2a --iam-instance-profile Name=jogoldbeAdmin4EC2 --tag-specifications "ResourceType=instance,Tags=[{Key=ctmenvironment,Value=${CTM_ENV}},{Key=ctmserver,Value=${ctmserver}},{Key=ctmhostgroup,Value=${CTM_HGRP}},{Key=Name,Value=ctmprod Control-M Agent}]"