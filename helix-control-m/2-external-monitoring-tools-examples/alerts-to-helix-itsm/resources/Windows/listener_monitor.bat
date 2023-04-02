@echo off

SETLOCAL EnableDelayedExpansion

REM Not logging the next line so it will be visible for user.
echo Entered the script at %date% %time%

REM Cycle between tests (5 minutes)
set cycle=300

REM Variables for log file
set filename=listener_monitor
set filedate=%date:/=-%
set filedate=%filedate:~4,10%

REM today for exit strategy
set today=%date%

REM Set parameter to Y if you want log to file in the % TEMP % directory 
REM TEMP directory depends on the user. It is C:\Windows\TEMP for local system account.
if .%1 == .Y (
	REM Set the log device
	set filedate=%date:/=-%
	set filedate=%filedate:~4,10%
	set "log_dev=>>%TEMP%\%filename%-%filedate%.log"
	set "log_file=%TEMP%\%filename%-%filedate%.log"
	REM And remove old logs. Note the minus sign (-7) to get days in the past
	FORFILES /P %TEMP% /D -7 /M %filename%*.log /C "cmd /c echo Removing @path && del @path" 
) else (
	REM Output to STDOUT (maybe driven from a job or output to console)
	set log_file=StdOut
	set log_dev=
)

REM Log start script time
echo Entered the script at %date% %time% %log_dev%
echo Logging to %log_file%


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
			REM Not logging the next line so it will be visible for user.
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
	REM Remove temp files
	del %TEMP%\statustmp.tmp
	del %TEMP%\status.tmp

	REM Making the time a number to allow for time comparison
	set now_time=%time::=%
	set now_time=%now_time:.=%
	
	REM The date comparison is a string
	if "%date%" == "%today%" (
		REM The time comparison is a number (as string 8:30 would be greater than 10:00)
		if %now_time% GTR 23590000 (
			echo Terminating the cycle on %date% at %time% [now=%now_time%] %log_dev%
			REM setting a timeout (60 + 10 seconds) to exit the next day
			REM   so the restarted script will not attempt to start on this same day
			REM Allowing to show the timeout count to the log file
			cmd /c "timeout /T 70 %log_dev%"
		) else (
			echo Entering wait for next cycle [%cycle% seconds] at %time% %log_dev%
			REM Redirect to NUL so it does not show the countdown.
			cmd /c "timeout /T %cycle% > NUL"
			REM Loop back to :start of the cycle
			goto start
		)
	) else (
		echo Terminating the cycle by change of day %date% %time% %log_dev%
	)
:end

REM if logging to file, log also to StdOut for the job to capture the entry
echo Exiting program at %date% %time% %log_dev%
if .%1 == .Y (
	echo Exiting program at %date% %time% 
)
:the_end
REM Stopping the listener and exiting with error (rc!=0) to cause restart, if service
call ctm run alerts:listener::stop 2>&1 %log_dev%
exit 42