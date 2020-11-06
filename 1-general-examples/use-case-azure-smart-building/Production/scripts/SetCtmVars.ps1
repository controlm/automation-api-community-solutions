param(
	[Parameter(Mandatory=$false)][Alias("rg")][String]$resourceGroupName = 'current',
	[Parameter(Mandatory=$false)][Alias("df")][String]$dataFactoryName = 'current'

)

if ($resourceGroupName -eq 'current') {
	$instanceMetaData = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -NoProxy -Uri http://169.254.169.254/metadata/instance?api-version=2019-11-01
	$resourceGroupName = $instanceMetaData.compute.resourceGroupName
}

if ($dataFactoryName -eq 'current') {
	$dfInfo = Get-AzDataFactoryV2 -ResourceGroupName $resourceGroupName
	$dataFactoryName = $dfInfo.DataFactoryName
}

ctmvar -ACTION SET -VAR %%\AZRG -VAREXPR "$resourceGroupName"
ctmvar -ACTION SET -VAR %%\AZDF -VAREXPR "$dataFactoryName"

