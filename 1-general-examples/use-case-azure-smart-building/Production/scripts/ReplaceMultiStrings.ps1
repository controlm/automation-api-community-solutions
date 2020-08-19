param(
	[Parameter(Mandatory=$true)][Alias("kf")][String]$kvFile,
	[Parameter(Mandatory=$true)][Alias("of")][String]$outFile,
	[Parameter(Mandatory=$true)][Alias("if")][String]$inFile	
)

$kvHash = @{}
[Int]$ctr = 0
foreach($kvLine in Get-Content $kvFile) {
	$k, $v = $kvLine -split ':'
	$kvHash.Add($k, $v)
}


foreach($inLine in Get-Content $inFile) {
	$updated = $false
	foreach ($kv in $kvHash.GetEnumerator()) {
		$k = $($kv.Name)
		$v = $($kv.Value)

		if ($inLine -match $k) {
			$ctr++
			$outLine = $inLine.Replace($k, "$v")
			Write-Host "Original: $inLine "
			Write-Host "Updated:  $outLine"
			$updated = $true
			break
		}
	}
	if (!$updated) {
		$updated = $false
		$outLine = $inLine
	}
	$outLine | Out-File $outFile -Append
}

Write-Host "Number of lines replaced: $ctr"