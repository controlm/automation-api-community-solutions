param(
	[Parameter(Mandatory=$true)][Alias("la")][String]$logicAppName,
	[Parameter(Mandatory=$true)][Alias("rg")][String]$resourceGroupName,
	[Parameter(Mandatory=$true)][Alias("rid")][String]$latestRun,
	[Parameter(Mandatory=$false)][Alias("sp")][String]$servicePrincipal,
	[Parameter(Mandatory=$false)][Alias("cs")][String]$clientSecret,
	[Parameter(Mandatory=$false)][Alias("tnt")][String]$tenantId
)

if ($servicePrincipal -ne '') {
	$password = ConvertTo-SecureString $clientSecret -AsPlainText -Force
	$pscredential = New-Object System.Management.Automation.PSCredential ($servicePrincipal, $password)
	Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId
	Write-Host "Connect-AzAccount performed with sp: $servicePrincipal and Tenant: $tenantId"
}

$laInfo = Get-AzLogicAppRunAction -ResourceGroupName $resourceGroupName -Name $logicAppName -RunName $latestRun
foreach ($action in $laInfo) {
	$aName = $action.Name
	$aSTime = $action.StartTime
	$aETime = $action.EndTime
	$aCode = $action.Code
	$aStatus = $action.Status
	Write-Host "=============================================================================================="
	Write-Host "Activity: `t$aName " 
	Write-Host "Status: `t$aStatus"
	Write-Host "Code: `t`t$aCode"
	Write-Host "Start: `t`t$aSTime `tEnd: $aETime "
	Write-Host "Activity Ouput:"
	Write-Host "=============================================================================================="
	$uri = $action.InputsLink.Uri
	$input = Invoke-RESTMethod -Uri "$uri" | ConvertTo-JSON
	$input
}