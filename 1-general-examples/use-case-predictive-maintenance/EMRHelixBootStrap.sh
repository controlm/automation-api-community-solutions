#!/bin/bash
set -e
HName=$(hostname -s)
ALIAS=jgo-$HName-$USER
sudo rm -r -f /tmp
sudo mkdir /tmp
sudo chmod 777 /tmp
curl --silent --location https://rpm.nodesource.com/setup_14.x | sudo bash -
sudo yum -y install nodejs
wget https://bmc-preprod-saas-agent-application-artifacts.s3.us-west-2.amazonaws.com/extracted/deployment315/root/apps/DEV/9.0.20.040/ctm-cli.tgz
sudo npm install -g ctm-cli.tgz
ctm env saas::add ctm https://se-americas-prod-aapi.prod.us1.preprod.ctmsaas.com/automation-api "UFBSR0JYOmJkM2M0MzdjLThhNTUtNDhjYi04Mjk5LTJiMzQxZTJkMjViOTp4aEF2T05URHlDNnJzUVNrODAwV1lqRFNFU2pwakVRcmdGajl1UUcyTVNzPQ=="
ctm env set ctm
ctm provision saas::install Agent_Amazon.Linux JGO_GCPAgents $ALIAS
ctm provision image Hadoop_plugin.Linux
# Define BMC Helix Control-M Environment
source /home/hadoop/.bash_profile
$CONTROLM/scripts/shut-ag -u hadoop -p all
ctm provision image MFT_plugin.Linux
$CONTROLM/scripts/start-ag -u hadoop -p ALL
ctm config server:hostgroup:agent::add IN01 hadooppm $ALIAS
aws s3 cp s3://623469066856-fy19seminar/emrkey $CONTROLM/cm/AFT/data/Keys/
aws s3 cp s3://623469066856-fy19seminar/emrkey.pub $CONTROLM/cm/AFT/data/authorized_keys
