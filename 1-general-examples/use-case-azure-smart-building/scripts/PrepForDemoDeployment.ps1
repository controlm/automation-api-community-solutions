param(
	[Parameter(Mandatory=$false)][Alias("l")][String]$location = 'West US 2',
	[Parameter(Mandatory=$false)][Alias("rg")][String]$resourceGroupName = 'FY21DEMO_RG',
	[Parameter(Mandatory=$false)][Alias("s")][String]$storageAccount = 'fy21stg009ab',
	[Parameter(Mandatory=$false)][Alias("drg")][Switch]$defineResourceGroup,
	[Parameter(Mandatory=$false)][Alias("t")][String]$templateFile = 'azuredeploy.json',
	[Parameter(Mandatory=$false)][Alias("p")][String]$templateParameterFile = 'azuredeploy_parameters.json',
	[Parameter(Mandatory=$false)][Alias("cf")][String]$credsFile = '.\azcreds.txt'
)
#$resourceGroupName = Read-Host -Prompt "Enter the Resource Group name"
#$location = Read-Host -Prompt "Enter the location (i.e. centralus)"

if ($defineResourceGroup.IsPresent) {
	New-AzResourceGroup -Name $resourceGroupName -Location $location
}
if ($templateParameterFile.ToLower() -eq 'none') {
	$Deployment_Output = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFile 
}
else {
	$Deployment_Output = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
	-TemplateFile $templateFile -TemplateParameterFile $templateParameterFile 
}

$storageAccountName = $Deployment_Output.Outputs.storageAccountName.Value

$sqlServerName = $Deployment_Output.Outputs.sqlServerName.Value

"Storage Account:"
$storageAccountName

"SQL Server Name:"
$sqlServerName