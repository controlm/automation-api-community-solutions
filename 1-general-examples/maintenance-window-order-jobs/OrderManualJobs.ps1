#
#	Fetch folder info via deploy jobs::get
#	Select folders that are "Manual" (Order Method not SYSTEM or a UserDaily
#	Examine each job for "FromTime" value
#	If a job's FromTime is earlier than "cutoffTime", skip the job
#		Otherwise order the job
#

#---------------------------------------------------------------------------------------------------------------------+
#	Parameters:                                                                                                       |
#		folder|fn			Name of the folder to process                                                             |
#		ctmName|ctm			Name of the Control-M Server                                                              |
#		cutoffTime|time		The time to use for determining if a job should be ordered or not                         |
#							'now" is the default and uses the current system time                                     |
#							'hh:mm" can be specified in 24-hour format, for any other time                            |
#		pswdfile|pf			Fully-qualified path of a file containing the Control-M username and password.            |
#							If not specified, a prompt is issued to cllect that information.                          |
#							The username is the first record and the password is the second record, for example:      |
#							ctmuser                                                                                   |
#							mypassword                                                                                |
#		method				'rest' or 'cli' to indicate if the installed and configured "ctm" cli is used             |
#							or direct REST API                                                                        |
#		endpoint			The fully-qualified name or IP address of the Control-M Enterprise Manager, used only     |
#							if method='rest' has been selected.                                                       |
#		test				Bypass the "ORDER" request and onoy produce an information message with job information   |
#		detail				Turn on detail messages                                                                   |
#---------------------------------------------------------------------------------------------------------------------+

param(
    [Parameter(Mandatory=$true)][Alias("fn")][String]$folder,
    [Parameter(Mandatory=$true)][Alias("ctm")][String]$ctmName,
    [Parameter(Mandatory=$false)][Alias("time")][String]$cutoffTime = 'now',
	[Parameter(Mandatory=$false)][Alias("pf")][String]$pswdFile = '.\pswd.txt',
	[Parameter(Mandatory=$false)][String]$method = 'cli',
	[Parameter(Mandatory=$false)][Alias("ep")][String]$endpoint = 'ec2-52-32-170-215.us-west-2.compute.amazonaws.com',
	[Parameter(Mandatory=$false)][Switch]$test,
	[Parameter(Mandatory=$false)][Switch]$detail
	
)

function CTM-Login 
{
	#
	#	Get username and password for CTM login
	#
	param ([String]$username,[String]$password, [String]$ctmURL)
	
	$login_data = @{ 
		username = $username; 
		password = $password}

	try
	{	
    #------------------------------------------------------------------------------------
    #  To accept self-signed certificates uncomment next line
    #
		$login_res = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri $ctmURL/session/login  -Body (ConvertTo-Json $login_data) -ContentType "application/json"
	}
	catch
	{
		$_.Exception.Message
		$error[0].ErrorDetails	
		$error[0].Exception.Response.StatusCode
		exit
	}
	
	$token = $login_res.token
	return $token
}

function Get-Credentials 
{
	if ($pswdFile -eq '') {
		$userName = Read-Host "Enter username for Control-M"
		$securepswd = Read-Host "Enter Password" -AsSecureString
		$password = ConvertFrom-SecureString -SecureString $securepswd -AsPlainText}
	else {
		$credsInFile = Get-Content -Path $pswdFile -TotalCount 2
		$userName = $credsInFile[0]
		$password = $credsInFile[1]
	}
	
	$creds = @($userName, $password)
	return $creds
}

function Order-Job
{
	param ([String]$method, [String]$folderName, [String]$jobName, [Switch]$test)
	
	if($test.IsPresent) {
		return
	}

	if ($method.ToLower() -eq "rest") {	
		$order_data = @{ 
			ctm = $ctmName; 
			folder = $foldername;
			jobs=$jobName}
	
		try
		{	
			$order_res = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri $ctmURL/run/order -Body (ConvertTo-JSON $order_data) -Headers $headers -ContentType "application/json" 	
		}
		catch
		{	
			Write-Host "Run Order failed: "	
			$order_res
			$error[0].ErrorDetails	
			$error[0].Exception.Response.StatusCode
			exit
		}
	}
	else {
		$ctmCmd = 'ctm run order ' + $ctmName + ' ' + $folder + ' ' + $jobName
		$ctmJSON = (cmd.exe /c $ctmCmd) | Out-String
	}
}

$jobFormat = 'xml'
$folderCount = 0
$jobCount = 0
if ($cutoffTime -eq "now") {
	$timeNow = Get-Date -uformat %R}
else {
	$timenow = $cutoffTime
}
Write-Host "Processing folder: $folder on Control-M server: $ctmName with cutoff time: $timenow"

Write-Host "Using XML format"

if ($method.ToLower() -eq "rest") {
	Write-Host "Using REST method"
	$ctmCreds = Get-Credentials
	
	$username = $ctmCreds[0]
	$password = $ctmCreds[1]
	$ctmURL = "https://" + $endpoint + ":8443/automation-api"
   
	$token = CTM-Login -username $username -password $password -ctmURL $ctmURL
	"Logged in successfully
	"
	$headers = @{ Authorization = "Bearer $token"}

	$deploy_data = @{ 
		format = "xml";
		ctm = $ctmName; 
		folder = $folder}
	try
	{	
		$deploy_res = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $ctmURL/deploy/jobs -Body ($deploy_data) -Headers $headers -ContentType "application/json" 
	
	}
	catch
	{
		
		Write-Host "Deploy GET failed: "	
		$deploy_res
		$error[0].ErrorDetails	
		$error[0].Exception.Response.StatusCode
		exit
	}
	Write-Host "Retrieved jobs successfully"

	$ctmXML = $deploy_res.OuterXML

}
else {
	Write "Using CLI method"

	$ctmCmd = 'ctm deploy jobs::get xml -s "ctm=' + $ctmName + '&folder=' + $folder + '"'
	$ctmXML = (cmd.exe /c $ctmCmd) | Out-String
}
#	
#	Check Regular Folder OrderMethod
#	Skip the folders that are not manual
#
$jobInfo = @()
$ctmFolder = Select-XML -Content $ctmXML -XPath "//FOLDER"
foreach($ctmFolderNode in $ctmFolder.node) 
{
	$ctmFolderName = $ctmFolderNode.FOLDER_NAME
	$folderCount += 1
	if ($ctmFolderNode.FOLDER_ORDER_METHOD -eq $null) {
		$ctmJobsXML = $ctmFolderNode.JOB
		if ($detail.IsPresent) {
			Write-Host "`tChecking folder $ctmFolderName for jobs because Order Method is Manual"
		}
		foreach($folder_job in $ctmJobsXML)
		{
			$ctmJob = $folder_job.JOBNAME
			$jobCount += 1
			if ($folder_job.TIMEFROM -ne $null) {
				$HH = $folder_job.TIMEFROM.Substring(0, 2)
				$MM = $folder_job.TIMEFROM.Substring(2,2)
				$jobFromTime = $HH + ":" + $MM
				$TimeDiff = New-TimeSpan $timeNow $jobFromTime 
				if ($TimeDiff.TotalSeconds -lt 0) {
					if ($detail.IsPresent) {
						write-host "`tSkipping job:  $ctmJob"
					}
				}
				else {
					if ($test.IsPresent) {
						Order-Job -method $method -folderName $ctmFolderName -jobName $ctmJob -test
						Write-Host "`nTesting job: $ctmJob `t FromTime: $jobFromTime `n"
					}
					else {
						Order-Job -method $method -folderName $ctmFolderName -jobName $ctmJob
						Write-Host "`nOrder job: $ctmJob `t FromTime: $jobFromTime `n"
					}
					$jobInfo += $ctmJob
				}
			}	
			else {
				if ($detail.IsPresent) {
					write-host "`tSkipping job:  $ctmJob"
				}
			}	
		}
	}
	else {
		if ($detail.IsPresent) {
			Write-Host "Folder $ctmFolderName skipped due to Order Method"
		}
	}
}
#	
#	Check Smart Folder OrderMethod
#	Skip the folders that are not manual
#
$ctmSmartFolder = Select-XML -Content $ctmXML -XPath "//SMART_FOLDER"
foreach($ctmFolderNode in $ctmSmartFolder.node) 
{
	$ctmFolderName = $ctmFolderNode.FOLDER_NAME
	$folderCount += 1
	if ($ctmFolderNode.FOLDER_ORDER_METHOD -eq $null) {
		$ctmJobsXML = $ctmFolderNode.JOB
		if ($detail.IsPresent) {
			Write-Host "`tChecking folder $ctmFolderName for jobs because Order Method is Manual"
		}
		foreach($folder_job in $ctmJobsXML)
		{
			$ctmJob = $folder_job.JOBNAME
			$jobCount += 1
			if ($folder_job.TIMEFROM -ne $null) {
				$HH = $folder_job.TIMEFROM.Substring(0, 2)
				$MM = $folder_job.TIMEFROM.Substring(2,2)
				$jobFromTime = $HH + ":" + $MM
				$TimeDiff = New-TimeSpan $timeNow $jobFromTime 
				if ($TimeDiff.TotalSeconds -lt 0) {
					if ($detail.IsPresent) {
						write-host "`tSkipping job:  $ctmJob"
					}
				}
				else {
					if ($test.IsPresent) {
						Order-Job -method $method -folderName $ctmFolderName -jobName $ctmJob -test
						Write-Host "`nTesting job: $ctmJob `t FromTime: $jobFromTime `n"
					}
					else {
						Order-Job -method $method -folderName $ctmFolderName -jobName $ctmJob
						Write-Host "`nOrder job: $ctmJob `t FromTime: $jobFromTime `n"
					}
					$jobInfo += $ctmJob
				}
			}	
			else {
				if ($detail.IsPresent) {
					write-host "`tSkipping job:  $ctmJob"
				}
			}	
		}
	}
	else {
		if ($detail.IsPresent) {
			Write-Host "Folder $ctmFolderName skipped due to Order Method"
		}
	}
}


Write-Host "`nNumber of jobs ordered: `t" $jobInfo.Count
Write-Host "Number of folders processed: `t" $folderCount
Write-Host "Number of jobs processed: `t" $jobCount
