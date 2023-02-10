echo NOTE: ENSURE YOU ADDD THE FULL PATH TO ALL THE FILES THAT NEED IT

echo Setting environment to ctmprd
ctm env set ctmprd

echo Setting up External Alert management for environment ctmprd
ctm run alerts:listener:environment::set ctmprd

echo NOTE: ENSURE YOU ADDD THE FULL PATH TO ALL THE FILES THAT NEED IT like here!
echo Setting up External Alert management script to extalerts.sh
ctm run alerts:listener:script::set extalerts.sh

echo NOTE: ENSURE YOU ADDD THE FULL PATH TO ALL THE FILES THAT NEED IT like here!
echo Setting up External Alert management template to field_names.json
ctm run alerts:stream:template::set -f field_names.json

echo Enabling External Alerts on BMC Helix Control-M
ctm config systemsettings::set enableExternalAlerts true

echo External Alerts status
ctm run alerts:stream::status

echo Closing External Alerts stream, if open
ctm run alerts:stream::close true

echo Explicitly opening  External Alerts stream
ctm run alerts:stream::open

echo Starting External Alerts listener
ctm run alerts:listener::start

echo External Alerts status, again. Should be OK.
ctm run alerts:stream::status

