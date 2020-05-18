#!/bin/bash
#
#	PART 1:	Build AMI used to launch Control-M Agent instances and have them
#			dynamically register with a Control-M environment as specified via 
#			EC2 Instance Tags
#
#           Really this should be done via Cloudformation.
#
#	ami-bf4193c7:	AWS Linux Quickstart AMI
#	vpc-6c02d60b:	a VPC for my account 
#	sg-31675d48:	Security Group in the above VPC
#                   Inbound open ports: 7005 Control-M Server-to-Agent port this agent may connect to
#                                         22 Optional - for SSH
#                                       3389 Optional - for RDP 
#
#	<Control-M Server>	Name of Control-M Server launched agents should connect to
#	<Hostgroup Name>	Control-M Hostgroup launched agents should join
#
#----------------------------------------------------------------------------------------+
#	Launch AWS Linux Instance                                                            |
#----------------------------------------------------------------------------------------+

aws ec2 run-instances --image-id ami-bf4193c7 --count 1 --instance-type t2.micro --key-name JoGoKey --security-group sg-31675d48 -ids --tag-specification 'ResourceType=instance,Tags=[{Key=Name,Value="AMI Build for CTM Agent"}]'

#	MANUAL ACTION:	Log in as ec2-user <=============================

#	Install node.js, Java 1.8 and ctm cli
sudo curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
sudo yum install -y nodejs

sudo yum install java-1.8.0
sudo yum remove java-1.7.0-openjdk

sudo wget https://ec2-52-32-170-215.us-west-2.compute.amazonaws.com:8443/automation-api/ctm-cli.tgz --no-check-certificate
sudo npm install -g ctm-cli.tgz

#	Configure ctm cli environment

ctm env add ctm "https://ec2-52-32-170-215.uss-west-2.compute.amazonaws.com:8443/automation-api" emuser empass
ctm env set ctm

#	configure aws cli
aws configure

sudo cp -r .aws /root

#	Install Control-M Agent
ctm provision image Agent.Linux
#
#	Pull rc.AWS_Agent_sample from Github
sudo curl -OL https://raw.githubusercontent.com/JoeGoldberg/automation-api-community-solutions/master/1-general-examples/use-case-predictive-maintenance/rc.AWS_Agent_sample
sudo mv rc.AWS_Agent_sample /etc/rc.d/init.d/ctmag-ec2-user

sudo chmod +x /etc/rc.d/init.d/ctmag-ec2-user
sudo chkconfig --level 345 ctmag-ec2-user

#	Ensure Control-M Server host name(s) resolve on newly launched instances
#	In demo environment, add to /etc/hosts:
#	172.31.12.47 controlm 
#
sudo vi /etc/hosts

#	Set Control-M environment and start Agent
source .bash_profile
start-ag 

#
#	Get Instance ID of machine we have been working on either from the AWS Console or via
#	curl http://169,254,169.254/latest/meta-data/instance-id

#	
#	From AWS Console or another machine, create new AMI
aws ec2 create-image --name "Control-M Agent" --description "AMI for launching a Control-M Agent" --instance-id <instance from machine above>

#
#	Part 2:	Launch Agent instances using the AMI created Above

aws ec2 run-instances --image-id ami-c070ddb8 --count 1 --instance-type t2.micro --key-name JoGoKey --security-group-ids sg-92b37dee --tag-specifications 'ResourceType=instance,Tags=[{Key=ctmenvironment,Value=ctmprod},{Key=ctmserver,Value=controlm},{Key=ctmhostgroup,Value=appgroup01},{Key=Name,Value="CTMPROD Control-M Agent"}]'

#	Monitor instance launch status via cli
aws ec2 describe-instances --instance-ids"<instance-id from above>" --query 'Reservations[0].Instances[0].PublicIpAddress'