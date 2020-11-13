param(
	[Parameter(Mandatory=$true)][Alias("rid")][String]$runId ,	
	[Parameter(Mandatory=$true)][Alias("df")][String]$dataFactoryName,
	[Parameter(Mandatory=$true)][Alias("rg")][String]$resourceGroupName
)
$timeNow = Get-Date -UFormat %D
$yesterday = (Get-Date).AddHours(-24) | Get-Date -UFormat %D
$tomorrow = (Get-Date).AddHours(24) | Get-Date -UFormat %D

$dfInfo = Get-AzDataFactoryV2ActivityRun -ResourceGroupName "$resourceGroupName" -DataFactoryName "$dataFactoryName" -PipelineRunId $runId -RunStartedAfter $yesterday -RunStartedBefore $tomorrow

foreach ($act in $dfInfo) {
	$aname = $act.ActivityName
	$aid = $act.ActivityRunId
	Write-Host "Activity: $aname `t" -noNewLine 
	Write-Host "RunID: $aid"
	Write-Host "=============================================================================================="
	$astart = $act.ActivityRunStart
	$aend = $act.ActivityRunEnd  
	$adur = $act.DurationInMs  
	$astatus = $act.Status 
	Write-Host "`tStatus: $astatus `tStart: $astart `tEnd: $aend `tDuration: $adur"
	Write-Host "Activity Ouput:"
	Write-Host "=============================================================================================="
	$jact = ConvertTo-JSON $act.Output
	$jact
}