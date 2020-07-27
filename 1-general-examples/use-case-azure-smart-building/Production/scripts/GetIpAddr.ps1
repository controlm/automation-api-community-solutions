$instanceMetaData = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -NoProxy -Uri http://169.254.169.254/metadata/instance?api-version=2019-11-01
$resourceGroupName = $instanceMetaData.compute.resourceGroupName
$computerName = $instanceMetaData.compute.name
$VMInfo = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name FY21CTMSDemoCopy_IP
$IpAddr = $VMInfo.IpAddress
