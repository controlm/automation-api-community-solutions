#! /bin/bash
set -x

source ~/.bash_profile


#crontab -l
#*/5 * * * * extalerts/listener_monitor.sh
# script does not finish... the script remains hanging and must be killed


status=`ctm run alerts:stream::status | grep 'status":'| awk -F '"' '{print $4}'`
ctmenv=`ctm env show | grep -i "current environment" | awk '{print $3}'`
echo `date` "- Alerts Listener for $ctmenv on $(hostname -f) wre being tested. Result $status" >> /tmp/listener_monitor.log

while [ ".$status" != ".OK" ]; do
   ctm run alerts:listener::stop
   echo `date` "- Alerts Listener for $ctmenv on $(hostname -f) was terminated." >> /tmp/listener_monitor.log
   # mailx -s "Alerts Listener for $ctmenv on $(hostname -f) was terminated" dcompane@bmc.com <<EOF
# No message
# EOF
   sleep 30
   status=`ctm run alerts:stream::status | grep 'status":'| awk -F '"' '{print $4}'`
done

