#!/bin/bash
sudo echo 52.12.7.249 ip-172-31-50-204.us-west-2.compute.internal >> /etc/hosts
sudo apt-get update
sudo apt-get install -yq openjdk-11-jdk wget psmisc
wget https://<your control-m em url>:8443/automation-api/ctm-cli.tgz --no-check-certificate
sudo curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs
GCP_Instance_ID=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google"`
iname=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google"`
zone=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google"`
CTM_ENV=`gcloud compute instances describe $(hostname) --zone=${zone} --format="text(labels)" | grep ctmenvironment | cut -f 2 -d ':' | sed s/[^a-zA-Z0-9_-]//g`
ctmhgroup=`gcloud compute instances describe $(hostname) --zone=${zone} --format="text(labels)" | grep ctmhostgroup | cut -f 2 -d ':' | sed s/[^a-zA-Z0-9_-]//g`
envurl=${CTM_ENV}-url
ctmurl=`gcloud secrets versions access latest --secret="${envurl}"`
envuser=${CTM_ENV}-user
ctmuser=`gcloud secrets versions access latest --secret="${envuser}"`
envpswd=${CTM_ENV}-password
ctmpswd=`gcloud secrets versions access latest --secret="${envpswd}"`
envsrvr=${CTM_ENV}-server
ctmserver=`gcloud secrets versions access latest --secret="${envsrvr}"`
envausr=${CTM_ENV}-agentuser
agentuser=`gcloud secrets versions access latest --secret="${envausr}"`
newhost="$(hostname).ctmgcpagents.com"
externalIp=`gcloud compute instances describe ${iname} --zone=${zone} --format='get(networkInterfaces[0].accessConfigs[0].natIP)'`
gcloud beta dns --project=sso-gcp-dba-ctm4-pub-cc10274 record-sets transaction start --zone="ctmgcpagents-com" && gcloud beta dns --project=sso-gcp-dba-ctm4-pub-cc10274 record-sets transaction add ${externalIp} --name="${newhost}" --ttl="300" --type="A" --zone="ctmgcpagents-com" && gcloud beta dns --project=sso-gcp-dba-ctm4-pub-cc10274 record-sets transaction execute --zone="ctmgcpagents-com"
sudo useradd -d /home/${agentuser} -m -s /bin/bash ${agentuser}
sudo wget https://smprod.ctmdemo.com:8443/automation-api/ctm-cli.tgz --no-check-certificate
sudo npm install -g ctm-cli.tgz
sudo su - ${agentuser} -c "ctm env add ctm ${ctmurl} ${ctmuser} ${ctmpswd}"
ALIAS=${newhost}:gcp-$GCP_Instance_ID
len=`expr length "${ALIAS}"`
if [[ $len -gt 85 ]]
then
	echo Agent name ${ALIAS} too long >> $GCP_LOG
	exit 99
else
    echo Agent name ${ALIAS} will be used
	echo Agent name ${ALIAS} will be used >> $GCP_LOG
fi
sudo su - ${agentuser} -c "ctm provision install Agent_20.200.Linux ${ctmserver} ${ALIAS}"
sudo su - ${agentuser} -c "ctm config server:hostgroup:agent::add ${ctmserver} ${ctmhgroup} ${ALIAS}"

echo STARTED > /home/ctmagent/ctm/data/ctm_agent_status.dat

sudo wget -O /etc/rc.d/init.d/ctmagent https://raw.githubusercontent.com/controlm/automation-api-community-solutions/master/3-infrastructure-as-code-examples/manage-workload-on-gcp/rc.GCP_Agent_sample

sudo chmod +x /etc/rc.d/init.d/ctmagent
sudo chkconfig --level 345 ctmagent on