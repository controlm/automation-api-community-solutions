#!/bin/bash

#--------------------------------------------------
#  Control-M/Agent Vagrant Provision
#--------------------------------------------------

export CTM_HOST="$1"

# Upgrade software packages
# This has been commented out to save time.  But it's recommended on outdated images.
# yum -y update 

# install basic packages
yum -y install wget \
	&& yum -y install unzip \
	&& yum -y install sudo \
	&& yum -y install net-tools \
	&& yum -y install which

# install nodejs
curl --silent --location https://rpm.nodesource.com/setup_10.x | bash - \
	&& yum -y install nodejs \
	&& node -v \
	&& npm -v

# install java 8 
yum -y install java-1.8.0-openjdk \
	&& java -version

# install Control-M Automation client globally
cd /root

rm -rf ctm-automation-api

mkdir ctm-automation-api \
	&& cd ctm-automation-api \
	&& wget --no-check-certificate https://$CTM_HOST:8443/automation-api/ctm-cli.tgz \
	&& npm install -g ctm-cli.tgz \
	&& ctm -v

# perform non-root install of Control-M/Agent after this
