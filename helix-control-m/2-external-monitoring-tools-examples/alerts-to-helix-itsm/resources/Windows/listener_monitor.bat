echo off

set cycle=300

set filedate=%date:/=-%
set filedate=%filedate:~4,10%

REM Set parameter to Y if you want log to file in the % TEMP % directory 
REM TEMP directory depends on the user. It is C:\Windows\TEMP for local system account.
if .%1 == .Y (
	set filedate=%date:/=-%
	set filedate=%filedate:~4,10%
    set "log_dev=>>%TEMP%\listener_alerts-%filedate%.log"
	set "log_message=file %TEMP%\listener_alerts-%filedate%.log"
) else (
	set log_dev=
	set log_message=StdOut
)

REM Not logging this to %log_dev% so it will be visible for user.
echo Logging to %log_message%

echo Entered the script at %date% %time% %log_dev%

:start
	echo Start cycle at %date% %time% %log_dev%
	echo Verifying alert listener status %log_dev%
	call ctm run alerts:stream::status > %TEMP%\statustmp.tmp
	type %TEMP%\statustmp.tmp %log_dev%

	findstr status %TEMP%\statustmp.tmp > %TEMP%\status.tmp
	set /p status=<%TEMP%\status.tmp
	set status=%status:~13,2%

	if NOT .%status% == .OK  (
		echo Status was found to be not OK %log_dev%
		REM if logging to file, log also to StdOut for the job to capture the entry
		if .%1 == .Y (
			echo Status was found to be not OK at %date% %time% 
		)
		echo Stoping the listener, just in case it is alive %log_dev% 
		REM More dramatically, the stream could be force closed and opened
		REM     call ctm run alerts:stream::close true 2>&1 %log_dev%
		REM     call ctm run alerts:stream::open 2>&1 %log_dev%
		REM		NOTE: stream::open is not needed, as listener::start opens the stream
		call ctm run alerts:listener::stop 2>&1 %log_dev%
		echo Starting the listener %log_dev%
		call ctm run alerts:listener::start 2>&1 %log_dev%
		REM The verification below is for display only. 
		REM		Status for action is not verified until next cycle.
		REM		This is why on failure, the next verification is in 30 seconds
		echo Verifying the listener after restart %log_dev%
		call ctm run alerts:stream::status 2>&1 %log_dev% 
		REM wait only for 30 seconds to retest
		set cycle=30
	) else (
		REM wait 300 seconds to retest
		set cycle=300
	)
	
	del %TEMP%\statustmp.tmp
	del %TEMP%\status.tmp

	set now=%time::=% 
	set now=%now:.=% 
	if  %now% GTR 23550000 (
		echo Terminating the cycle at end of day at %time% (now=%now%) %log_dev%
	) else (	
		echo Entering wait for next cycle (%cycle% seconds) %log_dev%
		timeout /T %cycle% /NOBREAK > NUL
		goto start
	)
	
:end

REM if logging to file, log also to StdOut for the job to capture the entry
echo Exiting cycle at %date% %time% %log_dev%
if .%1 == .Y (
	echo Exiting cycle at %date% %time% 
)
:the_end