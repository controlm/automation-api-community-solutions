## Error handling

### AAPI calls

Powershell has try/catch blocks for catching exceptions.
The following code shows an AAPI login and how to catch the exception if it
fails:

```
$login_data = @{ username = $username; password = $password	}
try {
	$login_res = Invoke-RestMethod -Method Post -Uri $endPoint/session/login  -Body (ConvertTo-Json $login_data) -ContentType "application/json"
}
catch {
	$_.Exception.Message
	$ErrorJSON = $error[0].ErrorDetails.Message | ConvertFrom-Json
	$ErrorJSON.errors[0].message
	exit 1
}
```

The same can be re-used for any AAPI call that uses `Invoke-RestMethod`

## Password obfuscation

The stand-alone script `storepass.ps1` asks the user for a password and stores
it encrypted in a file.

```
$filename="pass.txt"
Read-Host "Enter password" -assecurestring | convertfrom-securestring | out-file $filename
Write-Host "Password saved to ", $filename
```

Subsequently, the following code can be used to read the password from the file
and use it in your script:

```
$filename="pass.txt"   #file containing the secure password

$password = Get-Content $filename | ConvertTo-SecureString
$credentials = New-Object System.Net.NetworkCredential("dummy", $password, "dummy")

# $credentials.Password  now has the password that can be passed to other functions.
Write-Host "Password is", $credentials.Password
```

