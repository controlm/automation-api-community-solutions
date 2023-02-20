#! /bin/bash
set -x

source ~/.bash_profile

# add with crontab -e
#*/5 * * * * extalerts/listener_monitor.sh
# note that the environment must be sourced.
#crontab -l to see that it is set

status=`ctm run alerts:stream::status | grep 'status":'| awk -F '"' '{print $4}'`
ctmenv=`ctm env show | grep -i "current environment" | awk '{print $3}'`
echo `date` "- Alerts Listener for $ctmenv on $(hostname -f) are being tested. Result $status" >> /tmp/listener_monitor.log

while [ ".$status" != ".OK" ]; do
   ctm run alerts:listener::stop
   echo `date` "- Alerts Listener for $ctmenv on $(hostname -f) was terminated." >> /tmp/listener_monitor.log
   # mailx -s "Alerts Listener for $(ctm env show | grep -i "current environment" | awk '{print $3}') on $(hostname -f) was terminated" dcompane@bmc.com <<EOF
# No message
# EOF
   sleep 30
   status=`ctm run alerts:stream::status | grep 'status":'| awk -F '"' '{print $4}'`
done


