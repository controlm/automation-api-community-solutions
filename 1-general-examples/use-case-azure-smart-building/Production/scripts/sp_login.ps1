#
#	Log in to an Azure account using App Registration (Service Principal)

# Arguments:
#	t|tenantId 					Mandatory: Azure Tenant-ID
#
#	cf|credsFile				Fully-qualified path to a text file containing service principal and client secret, on seperate lines
#								If this parameter is not provided, a prompt is issued for the credentials.
#

param(	
	[Parameter(Mandatory=$false)][Alias("cf")][String]$credsFile = 'C:\Production\Data\azcreds.txt',
	[Parameter(Mandatory=$false)][Alias("pf")][String]$parmsFile = 'C:\Production\Data\demo_parms.cfg'
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

$azInfo = Get-AzContext
$subscription = $azInfo.Subscription.Id
$spSecret = $azCreds[2]

if ($lastRC -eq 0) {
	"Updating" 
	$tenantIdRecord = "xxxxtenantIDxxxx:$tenantId"
	$subscriptionRecord = "xxxxsubscriptionIDxxxx:$subscription"
	$spRecord = "xxxxservicePrincipalxxxx:$servicePrincipal"
	$spSecretRecord = "xxxxservicePrincipalClientSecretxxxx:$spSecret"
	
	$tenantIdRecord | Add-Content $parmsFile
	$subscriptionRecord | Add-Content $parmsFile
	$spRecord | Add-Content $parmsFile
	$spSecretRecord | Add-Content $parmsFile
}

