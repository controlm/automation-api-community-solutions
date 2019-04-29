#!/bin/bash -xe
### BEGIN INIT INFO
# Provides:          ctmenv
# Required-Start:    $all
# Required-Stop:
# Default-Start:     3 4 5
# Default-Stop:
# Short-Description: Initialize Control-M environment 
### END INIT INFO
exec 1>/var/lib/cloud/instance/rclog.out 2>&1
if [ ! -e /var/lib/cloud/instance/ctmdone.txt ]; then
    touch /var/lib/cloud/instance/ctmdone.txt
    CtmIP=$(cat /var/lib/cloud/instance/ctmprivateip.txt)
    echo $CtmIP controlm >> /etc/hosts
    MyHostname=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname | cut -d. -f1)
    apt-get -y install curl python-software-properties
    curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
    apt-get -y install nodejs
    add-apt-repository -y ppa:openjdk-r/ppa
    apt-get -y update
    apt-get -y install openjdk-8-jre
    useradd -d /home/ctmmft -m -s /bin/bash ctmmft
    echo 'ctmmft ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
    wget --no-check-certificate https://s3-us-west-2.amazonaws.com/623469066856-fy20seminar/ctm-cli.tgz
    npm install -g ctm-cli.tgz
    su - ctmmft -c "ctm env add ctmprod https://controlm:8443/automation-api apiuser rtcqlAC2"
    su - ctmmft -c "ctm prov agent::install Agent.Linux controlm $MyHostname"
    su - ctmmft -c "ctm config server:hostgroup::add controlm KafkaMaster $MyHostname"
fi
