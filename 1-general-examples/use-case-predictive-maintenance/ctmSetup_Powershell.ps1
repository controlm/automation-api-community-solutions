<powershell>
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
#----------------------------------------------------------------
#
#	Retrieve AWS Instance ID and EC2 instance Tags
#
#----------------------------------------------------------------
$AWS_Instance_ID = & Invoke-RestMethod http://169.254.169.254/latest/meta-data/instance-id
$Local_Hostname = & Invoke-RestMethod http://169.254.169.254/latest/meta-data/local-hostname
$ALIAS = $Local_Hostname.split(".")[0]

$Resp = & aws ec2 describe-tags --filters Name=resource-id,Values=$AWS_Instance_ID Name=key,Values=ctmserver
$RespToken = $Resp -split "\s+"
$CTM_SERVER = $RespToken[16] -replace '[",]',''

$Resp = & aws ec2 describe-tags --filters Name=resource-id,Values=$AWS_Instance_ID Name=key,Values=ctmhostgroup	
$RespToken = $Resp -split "\s+"
$CTM_HOSTGROUP = $RespToken[16] -replace '[",]',''

$Resp = & aws ec2 describe-tags --filters Name=resource-id,Values=$AWS_Instance_ID Name=key,Values=ctmenvironment	
$RespToken = $Resp -split "\s+"
$CTM_ENV = $RespToken[16] -replace '[",]',''

aws s3 cp s3://controlm-automationapi-tutorial-artifacts/$CTM_ENV.endpoint.secret c:\$CTM_ENV.endpoint.secret
$endpoint = & type c:\$CTM_ENV.endpoint.secret
aws s3 cp s3://controlm-automationapi-tutorial-artifacts/$CTM_ENV.username.secret c:\$CTM_ENV.username.secret
$username = & type c:\$CTM_ENV.username.secret
aws s3 cp s3://controlm-automationapi-tutorial-artifacts/$CTM_ENV.password.secret c:\$CTM_ENV.password.secret
$password = & type c:\$CTM_ENV.password.secret

del c:\$CTM_ENV.*.secret
Write-Host –NoNewLine "AWS Instance ID is " $AWS_Instance_ID
Write-Host ""
Write-Host –NoNewLine "Control-M Server is " $CTM_SERVER
Write-Host ""
Write-Host –NoNewLine "Hostgroup is " $CTM_HOSTGROUP
Write-Host ""
Write-Host –NoNewLine "Control-M Environment is " $CTM_ENV
Write-Host ""

ctm env del ctm
ctm env add ctm $endpoint $username $password

#------------------------------------------------------------------------------
#
#  Provision Agent request using Private DNS (Local hostname) + EC2 Instance ID
#
#------------------------------------------------------------------------------

$ALIAS=$ALIAS + ":" + $AWS_Instance_ID
Write-Host -NoNewLine "ALIAS is " $ALIAS
Write-Host ""

ctm provision setup $CTM_SERVER $ALIAS -e ctm
ctm config server:hostgroup:agent::add $CTM_SERVER $CTM_HOSTGROUP $ALIAS -e ctm
</powershell>