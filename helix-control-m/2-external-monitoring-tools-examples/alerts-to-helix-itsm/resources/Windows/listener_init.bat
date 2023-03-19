echo NOTE: ENSURE YOU ADDD THE FULL PATH TO ALL THE FILES THAT NEED IT

echo Setting environment to olas
call ctm env set olas

echo Setting up External Alert management for environment olas
call ctm run alerts:listener:environment::set olas

echo NOTE: ENSURE YOU ADDD THE FULL PATH TO ALL THE FILES THAT NEED IT like here!
echo Setting up External Alert management script to extalert.cmd
call ctm run alerts:listener:script::set %CD%\..\..\extalert.cmd

echo NOTE: ENSURE YOU ADDD THE FULL PATH TO ALL THE FILES THAT NEED IT like here!
echo Setting up External Alert management template to field_names.json
call ctm run alerts:stream:template::set -f %CD%\..\..\field_names.json

echo Enabling External Alerts on BMC Helix Control-M
call ctm config systemsettings::set -f %CD%\..\..\systemsettings.json

echo External Alerts status
call ctm run alerts:stream::status

echo Closing External Alerts stream, if open
call ctm run alerts:stream::close true

echo Explicitly opening  External Alerts stream
call ctm run alerts:stream::open

echo Starting External Alerts listener
call ctm run alerts:listener::start

echo External Alerts status, again. Should be OK.
call ctm run alerts:stream::status

