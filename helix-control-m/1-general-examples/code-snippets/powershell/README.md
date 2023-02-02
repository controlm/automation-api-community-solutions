## Error handling

### AAPI calls

Powershell has try/catch blocks for catching exceptions.
The following code shows a Control-M API request and how to catch the exception if it
fails:

```
$headers = @{ x-api-key = $apitoken}
try {
	$result = Invoke-RestMethod -Method Get -Uri "$endpoint/config/authorization/roles" -Headers $headers 
	$result.message
}
catch {
	$_.Exception.Message
	$errorJson = $error[0].ErrorDetails.Message | ConvertFrom-Json
	$errorJson.errors[0].message
	exit 1
}
```

The same can be re-used for any API call that uses `Invoke-RestMethod`


## Password obfuscation

The stand-alone script `storetoken.ps1` asks the user for a token and stores
it encrypted in a file.

```
$filename="token.txt"
Read-Host "Enter token" -assecurestring | convertfrom-securestring | out-file $filename
Write-Host "Token saved to ", $filename
```

Subsequently, the following code can be used to read the token from the file
and use it in your script:

```
$filename="token.txt"   #file containing the secure token

$apitoken = Get-Content $filename | ConvertTo-SecureString
$credentials = New-Object System.Net.NetworkCredential("dummy", $apitoken, "dummy")

# $credentials.Password  now has the password that can be passed to other functions.
Write-Host "Token is", $credentials.Password
```

