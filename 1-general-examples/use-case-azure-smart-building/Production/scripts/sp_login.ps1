#
#	Log in to an Azure account using App Registration (Service Principal)

# Arguments:
#	t|tenantId 					Mandatory: Azure Tenant-ID
#
#	cf|credsFile				Fully-qualified path to a text file containing service principal and client secret, on seperate lines
#								If this parameter is not provided, a prompt is issued for the credentials.
#

param(
	[Parameter(Mandatory=$false)][Alias("tnt")][String]$tenantId = '92b796c5-5839-40a6-8dd9-c1fad320c69b',	
	[Parameter(Mandatory=$false)][Alias("cf")][String]$credsFile = '.\azcreds.txt'
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

$azCreds = Get-Credentials	
$servicePrincipal = $azCreds[0]
$password = ConvertTo-SecureString $azCreds[1] -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential ($servicePrincipal, $password)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId