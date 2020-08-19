param(
	[Parameter(Mandatory=$true)][Alias("ns")][String]$newString,
	[Parameter(Mandatory=$true)][Alias("os")][String]$oldString,
	[Parameter(Mandatory=$true)][Alias("of")][String]$outFile,
	[Parameter(Mandatory=$true)][Alias("if")][String]$inFile	
)
	
foreach($inLine in Get-Content $inFile) {
	if ($inLine -match $oldString) {
		$outLine = $inLine.replace($oldString, $newString)    
	}
	else {
		$outLine = $inLine
	}
	$outLine | Out-File $outFile -Append
}