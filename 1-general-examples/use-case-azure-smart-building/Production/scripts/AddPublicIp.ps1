param(
	[Parameter(Mandatory=$true)][Alias("of")][String]$outFile,
	[Parameter(Mandatory=$false)][Alias("vm")][String]$vmName = 'FY21CTMSDemoCopy_IP'

)

#
#	Get Public IP via Instance Metadata
#
$instanceMetaData = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -NoProxy -Uri http://169.254.169.254/metadata/instance?api-version=2019-11-01
$resourceGroupName = $instanceMetaData.compute.resourceGroupName
$computerName = $instanceMetaData.compute.name
$vmInfo = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $vmName
$eCode = $?
if ($eCode) {
	$ipAddr = $vmInfo.IpAddress
	$ipAddrRecord = "xxxxctmPublicIpxxxx:$ipAddr"
	$ipAddrRecord | Add-Content $outFile
	exit(0)
} else {
	Write-Host "Interface $vmName not found in Resource Group $resourceGroupName"
	exit(1)
}