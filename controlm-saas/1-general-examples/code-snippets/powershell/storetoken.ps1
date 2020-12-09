#------------------------------------------------------------------------------------
#	Read token from user prompt and store it in file $filename
#------------------------------------------------------------------------------------
$filename="token.txt"

Read-Host "Enter token" -assecurestring | convertfrom-securestring | out-file $filename
Write-Host "Token saved to ", $filename
