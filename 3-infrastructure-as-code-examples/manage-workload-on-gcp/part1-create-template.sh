#!/bin/bash
#
#   ---------- NOTE ------------------- NOTE --------------------------- NOTE ----------------------
#   Do not execute this script.
#   This file is intended to provide sample commands that you can copy and modify before executing.
#   ---------- NOTE ------------------- NOTE --------------------------- NOTE ----------------------
#
# Create a GCP Compute Engine instance using a machine template installing a Control-M Agent with this bootstrap script
# Steps
# Launch a machine based on an Amazon Linux Quickstart AMI:
#   Provide an image-id for a base Linux machine for a Control-M agent
#   Choose an instance-type
#   Provide your own key name
#   Provide a security-group that should be assigned to Control-M agent machines

# Accomodate lackof DNS
sudo echo 52.12.7.249 ip-172-31-50-204.us-west-2.compute.internal >> /etc/hosts

# Install java, utilities including pstree and nodejs
sudo apt-get update
sudo apt-get install -yq openjdk-11-jdk wget psmisc
 
wget https://<your control-m em url>:8443/automation-api/ctm-cli.tgz --no-check-certificate

sudo curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# Retrieve the "ctm" cli installation package and install it
#   This is the URL for your Control-M Enterprise Manager 
sudo wget https://smprod.ctmdemo.com:8443/automation-api/ctm-cli.tgz --no-check-certificate
sudo npm install -g ctm-cli.tgz

# Add a user if desired
sudo useradd -d /home/ctmagent -m -s /bin/bash ctmagent
sudo su - ctmagent

#   Configure "ctm" environment - this is for building the AMI, not for eventual operation
ctm env add ctm smprod.ctmdemo.com:8443/automation-api apiuser 2Mzpah7msYUA94ZyzPztqBrn
#   ctm env set ctm

#   Install Control-M Agent using Automation API "provision" service
ctm provision image Agent_20.200.Linux

# Environment will be created with updated info at EC2 Launch Time
ctm env del ctm

# Make sure startup script starts the agent
echo STARTED > /home/ctmagent/ctm/data/ctm_agent_status.dat

# Modify te rc.AWS_Agent_sample in this folder for your environment:
# Copy it to /etc/rc.d/init.d/<control-m agent username>
sudo wget -O /etc/rc.d/init.d/ctmagent https://raw.githubusercontent.com/controlm/automation-api-community-solutions/master/3-infrastructure-as-code-examples/manage-workload-on-ec2/rc.AWS_Agent_sample

sudo chmod +x /etc/rc.d/init.d/ctmagent
sudo chkconfig --level 345 ctmagent on

# Get EC2 Instance ID from AWS console or via "curl http://169.254.169.254/latest/meta-data/instance-id" on the current machine
# Create "Control-M Agent" machine image (AMI) via AWS Console or the following AWS Cli command
AWS_Instance_ID=`curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | grep instanceId | cut -f 2 -d ':' | sed s/[^a-zA-Z0-9_-]//g`

aws ec2 create-image --name "Control-M Agent 9.0.20.200" --description "AMI for launching a Control-M Agent" --instance-id ${AWS_Instance_ID} --region us-west-2