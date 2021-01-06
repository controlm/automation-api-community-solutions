param(
	[Parameter(Mandatory=$false)][Alias("cf")][String]$credsFile = 'C:\Production\Data\azcreds.txt',
	[Parameter(Mandatory=$false)][Alias("l")][String]$location = 'West US 2',
	[Parameter(Mandatory=$false)][Alias("t")][String]$templateFile = 'azuredeploy.json',
	[Parameter(Mandatory=$false)][Alias("p")][String]$templateParameterFile = 'azuredeploy_parameters.json',
	[Parameter(Mandatory=$false)][Alias("of")][String]$outFile
)
function Get-Credentials 
{
	if ($credsFile -eq '') {
		$userName = Read-Host "Enter App Registration (Service Principal)"
		$securepswd = Read-Host "Enter Client Secret" -AsSecureString
		$password = ConvertFrom-SecureString -SecureString $securepswd -AsPlainText
	}
	else {
		$credsInFile = Get-Content -Path $credsFile -TotalCount 3
		if (-Not $?) {
			"Error reading creds"
			exit(20)
		}
		else { 	
			$userName = $credsInFile[0]
			$password = $credsInFile[1]
			$tenantId = $credsInFile[2]
		}
		
	}
	
	$creds = @($tenantId, $userName, $password)
	return $creds
}

Disconnect-AzAccount

$azCreds = Get-Credentials	
$tenantId = $azCreds[0]
$servicePrincipal = $azCreds[1]
$password = ConvertTo-SecureString $azCreds[2] -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential ($servicePrincipal, $password)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId
if ($?) {
	"Connect Account Successful"
	[Int]$lastRC = 0
}
else { 	
	"Connect Account Failed"
	exit(16)
}

$instanceMetaData = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -NoProxy -Uri http://169.254.169.254/metadata/instance?api-version=2019-11-01
$resourceGroupName = $instanceMetaData.compute.resourceGroupName

if ($templateParameterFile.ToLower() -eq 'none') {
	$deploymentOutput = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFile 
}
else {
	$deploymentOutput = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
	-TemplateFile $templateFile -TemplateParameterFile $templateParameterFile 
}

if (($outFile -ne '') -And ($deploymentOutput.ProvisioningState -eq "Succeeded")) {
	$storageAccountName = $deploymentOutput.Outputs.storageAccountName.Value
	$storageAccountKey = $deploymentOutput.Outputs.storageAccountKey.Value
	$sqlServerName = $deploymentOutput.Outputs.sqlServerName.Value
	$storageAccountNameRecord = "xxxxstorageAccountNamexxxx:$storageAccountName"
	$sqlServerNameRecord = "xxxxsqlnamexxxx:$sqlServerName"
	$storageAccountKeyRecord = "xxxxstorageAccountKeyxxxx:$storageAccountKey"
	
	$storageAccountNameRecord | Add-Content $outFile
	$storageAccountKeyRecord | Add-Content $outFile
	$sqlServerNameRecord | Add-Content $outFile
}

$deploymentOutput

if ($deploymentOutput.ProvisioningState -eq "Succeeded") {
	exit(0)
} else {
	exit(1)
}