#------------------------------------------------------------------------------------
#	Read stored password from file 
#------------------------------------------------------------------------------------
$filename="pass.txt"   #file containing the secure password

$password = Get-Content $filename | ConvertTo-SecureString
$credentials = New-Object System.Net.NetworkCredential("dummy", $password, "dummy")

# $credentials.Password  now has the password that can be passed to other functions.
Write-Host "Password is", $credentials.Password


