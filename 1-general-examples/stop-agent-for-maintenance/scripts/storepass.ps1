#------------------------------------------------------------------------------------
#	Read password from user prompt and store it in file $filename
#------------------------------------------------------------------------------------
$filename="pass.txt"

Read-Host "Enter password" -assecurestring | convertfrom-securestring | out-file $filename
Write-Host "Password saved to ", $filename
