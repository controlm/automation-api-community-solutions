#------------------------------------------------------------------------------------
#	Read stored token from file 
#------------------------------------------------------------------------------------
$filename="token.txt"   #file containing the secure token

$enctoken = Get-Content $filename | ConvertTo-SecureString
$credentials = New-Object System.Net.NetworkCredential("dummy", $enctoken, "dummy")

# $credentials.Password  now has the token that can be passed to other functions.
Write-Host "Token is", $credentials.Password


