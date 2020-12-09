#------------------------------------------------------------------------------------
# Example Code to read encrypted token from file and run a Control-M API request
#------------------------------------------------------------------------------------
# Use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$filename    = "token.txt"   #file containing the secure token
$encpassword = Get-Content $filename | ConvertTo-SecureString
$credentials = New-Object System.Net.NetworkCredential("dummy", $encpassword, "dummy")
$apitoken    = $credentials.Password
$endPoint    = 'https://YOURTENANT-aapi.us1.controlm.com/automation-api'

$headers = @{ "x-api-key"="$apitoken" }

# Example get roles request (make sure the token has config authorizations)
try {
	$result = Invoke-RestMethod -Method Get -Uri "$endpoint/config/authorization/roles" -Headers $headers 
	echo $result
}
catch {
	$_.Exception.Message
	$errorJson = $error[0].ErrorDetails.Message | ConvertFrom-Json
	echo $errorJson.Message
	exit 1
}

exit 0

