function Select-Environment 
{
	$envString = ""
	[String]$envInfo = ctm env sh
	$index = $envInfo.IndexOf('{')
	$envData = $envInfo.Substring($index)
	$envJson = ConvertFrom-Json $envData

	if ($envJson.psobject.properties.Name.Count -eq 1) {
		$envName = $envJson.psobject.properties.Name
		Write-Host "Using Default environment $envName"
	} else {
		Write-Host "Environments: "
		Write-Host "  Name `t`tUser `t`tendPoint"
		$envCtr = 0
		foreach ($env in $envJson.psobject.properties) {
			$envCtr++
			$eName = $env.Name
			$eUser = $env.Value.user
			$eEP = $env.Value.endPoint
			Write-Host "$envCtr $eName" -noNewLine
			if ($eName.Length -lt 6) {
				Write-Host "`t" -noNewLine
			}
			Write-Host "`t$eUser" -noNewLine
			if ($eUser.Length -lt 8) {
				Write-Host "`t" -noNewLine
			}
			Write-Host "`t$eEP "
		}	
		[Int]$envNum = Read-Host "Choose Environment number to use" 
		$envName = $envJson.psobject.properties.Name[$envNum - 1]
		Write-Host "Using environment $envName"
	}
	[String]$ctmInfo = ctm session login -e $envName
	$ctmJSON = ConvertFrom-JSON $ctmInfo
	$ctmVersion = $ctmJSON.version
	$version, $subVersion, $monthly = $ctmVersion -split '\.'
	
	return($envName, $subVersion, $monthly)
}

$envName, $subVersion, $monthly = Select-Environment
$folderFilter = Read-Host "Please enter a folder name or prefix to search. Enter to quit"
While ($folderFilter -ne "q") {
	if (($subVersion -eq 20) -And ($monthly -gt 15)) { 
		[String]$jobInfo = ctm run jobs:status::get -e $envName -s """ctm=*&folder=$folderFilter&deleted=false"""
	} else {
		[String]$jobInfo = ctm run jobs:status::get -e $envName -s """ctm=*&folder=$folderFilter"""
	}
	$jobHash = ConvertFrom-JSON $jobinfo
	[Int]$returnedJobs = $jobHash.returned
	
	if ($returnedJobs -gt 0) {
		$jobCtr = 0
		foreach ($job in $jobHash.statuses)
		{
			$jobCtr++
			Add-Member -InputObject $job -MemberType NoteProperty -Name sq -Value $jobCtr
		}
		$jobHash.statuses | Format-Table -RepeatHeader -Property sq, name, folder, status, jobId, application, subApplication, startTime, endTime, host, cyclic
		
		$jobSelect = 0
		While (($jobSelect -lt 1) -Or ($jobSelect -gt $returnedJobs)) {
			$jobSelect = Read-Host "Enter job sequence # to process"
		}
		
		$jobId = $jobHash.statuses.jobId[$jobSelect - 1]
		

		$function = Read-Host "Select action: b (Bypass), d (details), k (Kill), l (Log), n (Rerun now), o (Output), r (Rerun) or q (quit)"
		Switch ($function)
			{
				b {ctm run job::runNow $jobId}
				d {ctm run job:status::get $jobId}
				e {$envName, $subVersion, $monthly = Select-Environment}
				k {ctm run job::kill $jobId}
				l {ctm run job:log::get $jobId}
				n { 
					ctm run job::rerun $jobId
					ctm run job::runNow $jobId
				}
				o {ctm run job:output::get $jobId}
				r {ctm run job::rerun $jobId}
				Default {
					Write-Host "Valid selections are b (Bypass), d (details), k (Kill), l (Log), n (Rerun now), o (Output), r (Rerun) or q (quit)"
				}
			}

		
	} else {
		Write-Host "No jobs found to match folder=$folderFilter"
	}
	$saveFilter = $folderFilter
	$folderFilter = Read-Host "Please enter a folder name or prefix to search, Enter to repeat same criteria, q to quit"
	if ($folderFilter -eq "") {
		$folderFilter = $saveFilter
	}
} 
