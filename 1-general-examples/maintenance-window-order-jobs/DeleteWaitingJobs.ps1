param(
    [Parameter(Mandatory=$true)][Alias("a")][String]$ctmAppl,
    [Parameter(Mandatory=$true)][Alias("sa")][String]$ctmSubAppl,
	[Parameter(Mandatory=$true)][Alias("ctm")][String]$ctmName,
	[Parameter(Mandatory=$false)][Alias("s")][String]$ctmStatus = "Wait Workload"
)
	$ctmCmd = 'ctm run jobs:status::get -s "application=' + $ctmAppl + '&subApplication=' + $ctmSubAppl + '&status=' + $ctmStatus + '"'
	$ctmJSON = (cmd.exe /c $ctmCmd) | Out-String
	$ctmObj = ConvertFrom-Json -InputObject $ctmJSON
	$folderObj = $ctmObj.PSObject.Properties.Value
	foreach($job in $folderObj)
	{
		$jobId = $job.jobId
		$jobStatus = $job.status
		$jobDeleted = $job.deleted
		if ( ($jobStatus -eq $ctmStatus) -And (-not $jobDeleted) ) {
			Write-Host "Holding and deleting job: $jobId"
			$ctmCmd = 'ctm run job::hold ' + $jobId
			(cmd.exe /c $ctmCmd) | Out-String
			$ctmCmd = 'ctm run job::delete ' + $jobId
			(cmd.exe /c $ctmCmd) | Out-String
		}
	}
	
		