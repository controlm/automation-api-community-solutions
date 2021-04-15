param(
    [Parameter(Mandatory=$false)][Alias("kv")][String]$keyVault = 'jogoldbeVault',
    [Parameter(Mandatory=$false)][Alias("f")][String]$factory = 'FY21DemoADF-bjjumm6oar3mi',
    [Parameter(Mandatory=$false)][Alias("p")][String]$pipe = 'SmartBuilding_SparkPipeline'
)

# Authorize for KeyVault access
$response = Invoke-RESTMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net' -Method GET -Headers @{Metadata="true"}

$KvToken = $response.access_token
$apiVersion = 'api-version=2016-10-01'

# Get ADF Subscription
$secretName = $factory + "-subscription"
$url = "https://$keyVault.vault.azure.net/secrets/$secretName" + "?" + $apiVersion
$secret = Invoke-RESTMethod -Uri $url -Method GET -ContentType "application/json" -Headers @{ Authorization ="Bearer $KvToken"}
$subscription = $secret.value

# Get ADF Resource Group
$secretName = $factory + "-resourcegroup"
$url = "https://$keyVault.vault.azure.net/secrets/$secretName" + "?" + $apiVersion
$secret = Invoke-RESTMethod -Uri $url -Method GET -ContentType "application/json" -Headers @{ Authorization ="Bearer $KvToken"}
$rgroup = $secret.value

# Authorize for ADF Invocation
try {
    $response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -Method GET -Headers @{Metadata="true"}
}
catch
{
    $_.Exception.Message
    $error[0].ErrorDetails     
    $error[0].Exception.Response.StatusCode
    exit
}

$content = $response.Content | ConvertFrom-Json
$ArmToken = $content.access_token

$ctype = "application/json"
$headers = @{ Authorization ="Bearer $ArmToken"}

try {
    $adf_resp = Invoke-RESTMethod -Uri https://management.azure.com/subscriptions/$subscription/resourceGroups/$rgroup/providers/Microsoft.DataFactory/factories/$factory/pipelines/$pipe/createRun?api-version=2018-06-01 -Method POST -ContentType $ctype -Headers $headers
    $runid = $adf_resp.runId
    Write-Host "Data Factory $factory Pipeline $pipe Running $runid"
}
catch
{
    $_.Exception.Message
    $error[0].ErrorDetails     
    $error[0].Exception.Response.StatusCode
    exit
}