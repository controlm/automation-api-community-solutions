#------------------------------------------------------------------------------------
#	Stop scheduling jobs to a host during maintenance 
#------------------------------------------------------------------------------------
Param ( [Parameter(Mandatory=$True)] [ValidateNotNull()] $StopOrStart, [Parameter(Mandatory=$True)] [ValidateNotNull()] $CTMServer, [Parameter(Mandatory=$True)] [ValidateNotNull()] $AgentHost )

# To accept self-signed certificates uncomment next line
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$True}
# Control-M v19 accepts only TLS 1.2 by default:
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#----------------------------------------------------------------
$filename    ="pass.txt"   #file containing the secure password
$encpassword = Get-Content $filename | ConvertTo-SecureString
$credentials = New-Object System.Net.NetworkCredential("dummy", $encpassword, "dummy")
$password    = $credentials.Password
$username    = "sysadmin"
$endPoint    = "https://EMSERVER:8443/automation-api"

#----------------------------------------------------------------
$maxiterations = 300  # number of iterations the script will check if jobs are still running
$sleepinterval = 1    # number of seconds between each interval
#------------------------------------------------------------------------------------


#logout function to be called before each exit when we're already logged in
function ctmapi_logout {
	try {
		$result = Invoke-RestMethod -Method Post -Uri "$endpoint/session/logout" -Headers $headers 
	}
	catch {
		$_.Exception.Message
		$errorJson = $error[0].ErrorDetails.Message | ConvertFrom-Json
		$errorJson.errors[0].message
		exit 1
	}
}

# Login 
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
$token= $login_res.token
$headers = @{ Authorization = "Bearer $token"}

# Selected action is start or stop
switch ( $StopOrStart )
{
	stop 
	{
		# Check if Agent exists
		try {	
			$agent_res = Invoke-RestMethod -Method Get -Uri "$endpoint/config/server/$CTMServer/agents?agent=$AgentHost"  -Headers $headers
		}
		catch {
			$_.Exception.Message
			$ErrorJSON = $error[0].ErrorDetails.Message | ConvertFrom-Json
			$ErrorJSON.errors[0].message
			ctmapi_logout
			exit 1
		}
		if( !$agent_res.agents.nodeid ) {
			Write-Output "No Agent named ""$($AgentHost)"" found in Control-M/Server ""$($CTMServer)"""
			ctmapi_logout
			exit 1
		} 

		# Check if jobs are still running on the Agent
		$i = 0
		do {
			$result = Invoke-RestMethod -Uri "$endpoint/run/jobs/status?host=$agenthost&status=Executing" -Headers $headers 
			$runningJobs=$result.returned
			Write-Progress " $runningJobs jobs still running on $($AgentHost). "
			$i++
		} until (($runningJobs -le 0) -or ($i -ge $maxiterations))
		if ( $result.returned -gt 0 ) {
			Write-Output "$($result.returned) jobs still running on $($AgentHost). Contact your Control-M Administrator."
			ctmapi_logout
			exit 1
		}
		else {
			Write-Output "No jobs running on $($AgentHost). Disabling Agent..."

	                # Disable the Agent
	                try {
	                        $result = Invoke-RestMethod -Method Post -Uri "$endpoint/config/server/$CTMServer/agent/$AgentHost/disable" -Headers $headers
	                        $result.message
	                }
	                catch {
	                        $_.Exception.Message
	                        $errorJson = $error[0].ErrorDetails.Message | ConvertFrom-Json
	                        $errorJson.errors[0].message
	                        ctmapi_logout
	                        exit 1
	                }

		}
	}

	start
	{
	    try {
			$result = Invoke-RestMethod -Method Post -Uri "$endpoint/config/server/$CTMServer/agent/$AgentHost/enable" -Headers $headers 
			$result.message
		}
		catch {
			$_.Exception.Message
			$errorJson = $error[0].ErrorDetails.Message | ConvertFrom-Json
			$errorJson.errors[0].message
			ctmapi_logout
			exit 1
		}
	}
	
	default
	{   
		Write-Output "Usage: $($MyInvocation.MyCommand.Name) stop|start ctmserver agent"
	}

}

ctmapi_logout
exit 0
