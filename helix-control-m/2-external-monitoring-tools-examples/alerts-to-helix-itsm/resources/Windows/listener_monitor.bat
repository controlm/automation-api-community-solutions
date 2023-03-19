echo off

set cycle=300

date /T >> %TEMP%\listener_alerts.log
time /T >> %TEMP%\listener_alerts.log
echo "Starting the checking cycle" >> %TEMP%\listener_alerts.log

:Start

date /T >> %TEMP%\listener_alerts.log
time /T >> %TEMP%\listener_alerts.log
echo "Entered the cycle" >> %TEMP%\listener_alerts.log

call ctm run alerts:stream::status > %TEMP%\statustmp.tmp
findstr status %TEMP%\statustmp.tmp > %TEMP%\status.tmp
set /p statustmp=<%TEMP%\status.tmp
set status=%statustmp:~13,2%

type %TEMP%\statustmp.tmp >> %TEMP%\listener_alerts.log

if NOT .%status% == .OK  (
   set cycle=30
   echo "Stoping service, just in case it is alive" >> %TEMP%\listener_alerts.log
   call ctm run alerts:listener::stop 2>&1 >> %TEMP%\listener_alerts.log
   echo "Starting service" >> %TEMP%\listener_alerts.log
   call ctm run alerts:listener::start 2>&1 >> %TEMP%\listener_alerts.log
   echo "Verifying service" >> %TEMP%\listener_alerts.log
   call ctm run alerts:stream::status 2>&1 >> %TEMP%\listener_alerts.log
) else (
   set cycle=300
)

del %TEMP%\statustmp.tmp
del %TEMP%\status.tmp


echo "Entering wait for next cycle (%cycle% seconds)" >> %TEMP%\listener_alerts.log
waitfor /T %cycle% Wait4Cycle

goto Start

echo "Exiting cycle" >> %TEMP%\listener_alerts.log
:the_end