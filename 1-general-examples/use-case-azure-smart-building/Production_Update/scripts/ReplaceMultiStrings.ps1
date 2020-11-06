param(
	[Parameter(Mandatory=$true)][Alias("kf")][String]$kvFile,
	[Parameter(Mandatory=$true)][Alias("of")][String]$outFile,
	[Parameter(Mandatory=$true)][Alias("if")][String]$inFile	
)

$kvHash = @{}
[Int]$ctr = 0

if (Test-Path -Path $kvFile) {
	foreach($kvLine in Get-Content $kvFile) {
		$k, $v = $kvLine -split ':'
		$kvHash.Add($k, $v)
	}
} else {
	Write-Host "Key/Value File not found: $kvFile "
	exit(1)
}

if (Test-Path -Path $inFile) {
	foreach($inLine in Get-Content $inFile) {
		$updated = $false
		foreach ($kv in $kvHash.GetEnumerator()) {
			$k = $($kv.Name)
			$v = $($kv.Value)

			if ($inLine -match $k) {
				if ($v -ne "") {
					$ctr++
					$outLine = $inLine.Replace($k, "$v")
					Write-Host "Original: $inLine "
					Write-Host "Updated:  $outLine"
					$updated = $true
					break
				} else {
					Write-Host "Keyword $k has a null value"
					exit(1)
				}
			}
		}
		if (!$updated) {
			$updated = $false
			$outLine = $inLine
		}
		$outLine | Out-File $outFile -Append
	}
} else {
	Write-Host "InputFile not found: $inFile "
	exit(2)
}

Write-Host "Number of lines replaced: $ctr"