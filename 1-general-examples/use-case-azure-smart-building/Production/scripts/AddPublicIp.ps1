param(
	[Parameter(Mandatory=$true)][Alias("of")][String]$outFile,
	[Parameter(Mandatory=$false)][Alias("cf")][String]$credsFile = '.\azcreds.txt',
	[Parameter(Mandatory=$false)][Alias("tnt")][String]$tenantId = '92b796c5-5839-40a6-8dd9-c1fad320c69b',	
	[Parameter(Mandatory=$false)][Alias("l")][String]$location = 'West US 2',
	[Parameter(Mandatory=$false)][Alias("vm")][String]$vmName = 'FY21CTMSDemoCopy_IP'

)
function Get-Credentials 
{
	if ($credsFile -eq '') {
		$userName = Read-Host "Enter App Registration (Service Principal)"
		$securepswd = Read-Host "Enter Client Secret" -AsSecureString
		$password = ConvertFrom-SecureString -SecureString $securepswd -AsPlainText
	}
	else {
		try {
			$credsInFile = Get-Content -Path $credsFile -TotalCount 2
		}
		catch {
			"Some error occurred"
			$_.Exception.Message
			exit
		}
		$userName = $credsInFile[0]
		$password = $credsInFile[1]
	}
	
	$creds = @($userName, $password)
	return $creds
}

#
#	Get AppRegistration and Client Secret, then connect to an Azure account
#
$azCreds = Get-Credentials	
$servicePrincipal = $azCreds[0]
$password = ConvertTo-SecureString $azCreds[1] -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential ($servicePrincipal, $password)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId

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