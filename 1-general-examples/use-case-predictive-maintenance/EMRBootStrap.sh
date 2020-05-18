#!/bin/bash
set -e
ALIAS=$(hostname)
cp /etc/hosts ./thosts
echo 172.1.12.249 controlm >> thosts
sudo cp thosts /etc/hosts
curl --silent --location https://rpm.nodesource.com/setup_9.x | sudo bash -
sudo yum -y install nodejs
wget --no-check-certificate https://controlm:8443/automation-api/ctm-cli.tgz
sudo npm install -g ctm-cli.tgz
ctm env add ctm https://controlm:8443/automation-api username password
ctm env set ctm
ctm provision install BigDataAgent.Linux controlm 
ctm config server:hostgroup:agent::add controlm hadoop $ALIAS
