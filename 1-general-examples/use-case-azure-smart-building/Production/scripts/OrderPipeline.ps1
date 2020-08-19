param(
	[Parameter(Mandatory=$true)][Alias("rg")][String]$resourceGroupName,
	[Parameter(Mandatory=$false)][Alias("cf")][String]$parmsFile = '.\demo_parms.cfg',
	[Parameter(Mandatory=$false)][Alias("vf")][String]$varsFile = '.\ctmvars.json'

)
$varsLine = "{"
$varsLine | Out-File $varsFile
$varsLine = "`t""Variables"": ["
$varsLine | Out-File $varsFile -Append
$varsLine = "`t`t{""AZRG"": ""$resourceGroupName""},"
$varsLine | Out-File $varsFile -Append

foreach($kvLine in Get-Content $parmsFile) {
	$k, $v = $kvLine -split ':'
	if ($k -eq "xxxxdataFactoryNamexxxx") {
		$varsLine = "`t`t{""AZDF"": ""$v""}"
		$varsLine | Out-File $varsFile -Append
	}
}

$varsLine = "`t],"
$varsLine | Out-File $varsFile -Append

$varsLine = "`t""ignoreCriteria"": ""false"""
$varsLine | Out-File $varsFile -Append

$varsLine = "}"
$varsLine | Out-File $varsFile -Append

ctm run order FY21CTMServer SMB_Pipeline -f $varsFile