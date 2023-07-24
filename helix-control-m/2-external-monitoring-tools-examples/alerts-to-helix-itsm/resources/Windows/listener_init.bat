echo NOTE: ENSURE YOU ADD THE FULL PATH TO ALL THE FILES THAT NEED IT

echo on

REM ensure you use the fqdn of your tenant for aapi
REM    you can find that information on the configuration section
REM    of the Automation API 
set env_name=%1
set host_name=%2
set "token=%3"

echo Creating the environment
call ctm environment delete %env_name%
call ctm environment saas::add %env_name% https://%hostname%/automation-api %token%

echo on
echo Setting environment to %env_name%
call ctm env set %env_name%

echo on
echo Setting up External Alert management for environment %env_name%
call ctm run alerts:listener:environment::set %env_name%

echo on
echo NOTE: ENSURE YOU ADD THE FULL PATH TO ALL THE FILES THAT NEED IT like here!
echo Setting up External Alert management script to extalert.cmd
call ctm run alerts:listener:script::set "C:\alerts-to-helix-itsm\extalert.cmd"

echo on
echo NOTE: ENSURE YOU ADD THE FULL PATH TO ALL THE FILES THAT NEED IT like here!
echo Setting up External Alert management template to field_names.json
call ctm run alerts:stream:template::set -f "C:\alerts-to-helix-itsm\field_names.json"

echo on
echo Enabling External Alerts on BMC Helix Control-M
call ctm config systemsettings::set "C:\alerts-to-helix-itsm\systemsetting.json"

echo on
echo Closing External Alerts stream, if open
call ctm run alerts:stream::close true

echo on
echo External Alerts status
call ctm run alerts:stream::status

echo on
echo Explicitly opening  External Alerts stream
call ctm run alerts:stream::open
