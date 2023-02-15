#! /bin/bash
set -x

status=`ctm run alerts:stream::status | grep 'status":'| awk -F '"' '{print $4}'`

while [ ".$status" != ".OK" ]; do
   ctm run alerts:listener::stop
   ctmenv=`ctm env show | grep -i "current environment" | awk '{print $3}'`
   mailx -s "Alerts Listener for $ctmenv on $(hostname -f) was terminated" dcompane@bmc.com <<EOF
No message
EOF
   sleep 30
   status=`ctm run alerts:stream::status | grep 'status":'| awk -F '"' '{print $4}'`
done
