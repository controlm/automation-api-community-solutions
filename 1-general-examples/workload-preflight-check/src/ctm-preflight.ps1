#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CTM Engineer Demo - PowerShell 7 port of the Postman pre-flight validation script.

.DESCRIPTION
    Mirrors the logic in the Postman collection "Workload PreFlight Check":
      - Pulls deployed jobs for a folder (all types, not just FileTransfer)
      - Resolves each job's Host (always a hostgroup) to its first agent member
      - Tests agent reachability for every job that has a Host
      - For Job:FileTransfer only, also tests ConnectionProfileSrc / ConnectionProfileDest
      - For FileTransfer jobs whose connection profile Type contains "SFTP", also runs a
        network reachability test (ICMP ping + TCP port-connect) against the profile's
        HostName/Port, resolved via the live CCP endpoint (not job Variables)
      - Jobs with no Host field (Job:SLAManagement, Job:Dummy, etc.) are reported as SKIPPED
      - Prints a color-coded console report, and writes a timestamped JSON report
        to {script folder}/.engineer/log/

.PARAMETER Folder
    The Control-M folder name to validate. The only required parameter.

.PARAMETER Output
    Controls what gets printed to the console. One of:
      verbose (default) - full human-readable console report (per-job progress, summary,
                           color-coded table, unique resources tested, then the JSON report path)
      json    - prints only the JSON report content (nothing else)
      file    - prints only the path to the JSON report file (nothing else)
    The JSON report file is always written to disk regardless of this setting.

.EXAMPLE
    ./ctm_preflight.ps1 -Folder ZZM_UC_MULTIPATH_CLOUD

.EXAMPLE
    ./ctm_preflight.ps1 -Folder ZZM_UC_MULTIPATH_CLOUD -Output json

.NOTES
    Requires a .env file at {script folder}/.engineer/config/.env (or pass -EnvFile to point elsewhere) containing:
        baseUrl=https://your-ctm-api-host
        apiKey=your-api-key
        CTM_SERVER=ctm-lin-srv
        SFTP_PORT=22        (optional, used only when a connection profile has no explicit Port)
        FTP_PORT=21         (optional, reserved)
        MFT_PORT=1222       (optional, reserved)
        LOG_FOLDER=.engineer/logs  (optional, relative to this script's location; defaults to .engineer/logs)

    The JSON report is written to the resolved LOG_FOLDER, timestamped per run.
    This version does NOT send alerts anywhere (Control-M's Automation API only supports
    updating existing alerts, not creating new ones - there is no alert-creation endpoint).

    IMPORTANT: The SFTP network test (ping + port) only proves reachability FROM THE MACHINE
    RUNNING THIS SCRIPT. It does NOT confirm the Control-M agent itself can reach these hosts -
    the agent's actual network path (segment, firewall, NAT) may differ entirely.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Folder,

    [Parameter(Mandatory = $false)]
    [string]$EnvFile = (Join-Path $PSScriptRoot ".engineer" "config" ".env"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("verbose", "json", "file")]
    [string]$Output = "verbose"
)

$ErrorActionPreference = "Stop"

$Folder = $Folder.Trim()

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------
function Import-DotEnv {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Could not find .env file at: $Path"
    }

    $envVars = @{}
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        # strip surrounding quotes if present
        if ($val.StartsWith('"') -and $val.EndsWith('"')) { $val = $val.Substring(1, $val.Length - 2) }
        if ($val.StartsWith("'") -and $val.EndsWith("'")) { $val = $val.Substring(1, $val.Length - 2) }
        $envVars[$key] = $val
    }
    return $envVars
}

$config = Import-DotEnv -Path $EnvFile

foreach ($required in @("baseUrl", "apiKey", "CTM_SERVER")) {
    if (-not $config.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($config[$required])) {
        throw "Missing required key '$required' in $EnvFile"
    }
}

$BaseUrl = $config["baseUrl"].TrimEnd("/")
$ApiKey  = $config["apiKey"]
$Server  = $config["CTM_SERVER"]
$CcpType = "FileTransfer"   # matches CTM_APP_TYPE constant from the source tool

# Network test port definitions - SFTP is the only one wired into gating logic today;
# FTP_PORT/MFT_PORT are accepted now so a later expansion doesn't need a second .env migration
$SftpPort = if ($config.ContainsKey("SFTP_PORT") -and $config["SFTP_PORT"]) { [int]$config["SFTP_PORT"] } else { 22 }
$FtpPort  = if ($config.ContainsKey("FTP_PORT")  -and $config["FTP_PORT"])  { [int]$config["FTP_PORT"] }  else { 21 }
$MftPort  = if ($config.ContainsKey("MFT_PORT")  -and $config["MFT_PORT"])  { [int]$config["MFT_PORT"] }  else { 1222 }

$Headers = @{
    "x-api-key"    = $ApiKey
    "Content-Type" = "application/json"
}

# Reports (JSON + HTML) are written here, created if it doesn't already exist.
# LOG_FOLDER in .env is optional and resolved relative to this script's location;
# if omitted, defaults to .engineer/logs.
$LogFolderRelative = if ($config.ContainsKey("LOG_FOLDER") -and $config["LOG_FOLDER"]) { $config["LOG_FOLDER"] } else { Join-Path ".engineer" "logs" }
$LogFolder = Join-Path $PSScriptRoot $LogFolderRelative
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Console color helpers
# ---------------------------------------------------------------------------
function Write-Badge {
    param([string]$Text, [string]$State)
    # Uses explicit 24-bit RGB ANSI escapes rather than -ForegroundColor/ConsoleColor names.
    # Some terminals (confirmed: Terminus) remap the basic 16-color ANSI palette in ways that
    # flatten Red/Green/Yellow toward the same hue, while true RGB escapes render correctly.
    $esc = [char]27
    $rgb = switch ($State) {
        "ok"    { "0;200;0" }     # green
        "warn"  { "230;180;0" }   # yellow/amber
        "error" { "220;0;0" }     # red
        default { "150;150;150" } # gray
    }
    $padded = $Text.PadRight(4)
    Write-Host "$esc[38;2;${rgb}m [$padded] $esc[0m" -NoNewline
}

function Write-ColorText {
    param([string]$Text, [string]$ColorName, [switch]$NoNewline)
    # Same RGB-escape approach as Write-Badge, but accepts the existing named color strings
    # ("Green"/"Red"/"Yellow"/"Cyan"/"DarkGray") already used throughout this script, so call
    # sites and their upstream variable assignments don't need to change - only how they print.
    $esc = [char]27
    $rgb = switch ($ColorName) {
        "Green"    { "0;200;0" }
        "Red"      { "220;0;0" }
        "Yellow"   { "230;180;0" }
        "Cyan"     { "0;190;210" }
        "DarkGray" { "120;120;120" }
        default    { "200;200;200" }
    }
    if ($NoNewline) {
        Write-Host "$esc[38;2;${rgb}m${Text}$esc[0m" -NoNewline
    } else {
        Write-Host "$esc[38;2;${rgb}m${Text}$esc[0m"
    }
}
$BadgeColumnWidth = 10  # must be > 9 since "AgentTest" header label is itself 9 chars

# ---------------------------------------------------------------------------
# Step 1: recursively extract ALL jobs from the nested folder structure
# ---------------------------------------------------------------------------
function Get-AllNodes {
    param($Node, [string]$ParentName)

    $results = @()

    # Handle arrays
    if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string] -and $Node -isnot [hashtable]) {
        foreach ($item in $Node) {
            $results += Get-AllNodes -Node $item -ParentName $ParentName
        }
        return $results
    }

    if ($null -eq $Node -or $Node -isnot [psobject]) { return $results }

    $nodeName = if ($Node.PSObject.Properties.Name -contains "Name") { $Node.Name } else { $ParentName }

    # Extract SubFolders as first-class graph nodes before recursing into their contents
    if ($Node.PSObject.Properties.Name -contains "SubFolders" -and $Node.SubFolders) {
        foreach ($sf in $Node.SubFolders) {
            $sfName = $sf.Name
            $results += [PSCustomObject]@{
                Name                  = $sfName
                Type                  = "SubFolder"
                Host                  = ""
                Parent                = $nodeName
                ConnectionProfileSrc  = ""
                ConnectionProfileDest = ""
                IsSubFolder           = $true
                EventsProduced        = if ($sf.PSObject.Properties.Name -contains "eventsToAdd" -and $sf.eventsToAdd.Events) {
                                            $sf.eventsToAdd.Events | ForEach-Object { $_.Event }
                                        } else { @() }
                EventsConsumed        = if ($sf.PSObject.Properties.Name -contains "eventsToWaitFor" -and $sf.eventsToWaitFor.Events) {
                                            $sf.eventsToWaitFor.Events | ForEach-Object { $_.Event }
                                        } else { @() }
            }
            # Recurse into SubFolder contents
            $results += Get-AllNodes -Node $sf -ParentName $sfName
        }
    }

    # Extract Jobs
    if ($Node.PSObject.Properties.Name -contains "Jobs" -and $Node.Jobs) {
        foreach ($job in $Node.Jobs) {
            $results += [PSCustomObject]@{
                Name                  = $job.Name
                Type                  = $job.Type
                Host                  = if ($job.PSObject.Properties.Name -contains "Host") { $job.Host } else { "" }
                Parent                = $nodeName
                ConnectionProfileSrc  = if ($job.PSObject.Properties.Name -contains "ConnectionProfileSrc") { $job.ConnectionProfileSrc } else { "" }
                ConnectionProfileDest = if ($job.PSObject.Properties.Name -contains "ConnectionProfileDest") { $job.ConnectionProfileDest } else { "" }
                IsSubFolder           = $false
                EventsProduced        = if ($job.PSObject.Properties.Name -contains "eventsToAdd" -and $job.eventsToAdd.Events) {
                                            $job.eventsToAdd.Events | ForEach-Object { $_.Event }
                                        } else { @() }
                EventsConsumed        = if ($job.PSObject.Properties.Name -contains "eventsToWaitFor" -and $job.eventsToWaitFor.Events) {
                                            $job.eventsToWaitFor.Events | ForEach-Object { $_.Event }
                                        } else { @() }
            }
        }
    }

    # Recurse into other structural properties (Folders, etc.) but not Jobs/SubFolders (already handled)
    foreach ($prop in $Node.PSObject.Properties) {
        if ($prop.Name -in @("Jobs", "SubFolders", "Name", "Type")) { continue }
        if ($prop.Value -is [System.Collections.IEnumerable] -and $prop.Value -isnot [string]) {
            $results += Get-AllNodes -Node $prop.Value -ParentName $nodeName
        } elseif ($prop.Value -is [psobject] -and $prop.Value.PSObject.Properties.Name -contains "Jobs") {
            $results += Get-AllNodes -Node $prop.Value -ParentName $nodeName
        }
    }

    return $results
}

function Get-AllJobs {
    # Returns only job nodes (not SubFolders) for the validation/testing pipeline
    param($Node, [string]$ParentName)
    return Get-AllNodes -Node $Node -ParentName $ParentName | Where-Object { -not $_.IsSubFolder }
}

# ---------------------------------------------------------------------------
# API calls
# ---------------------------------------------------------------------------
function Invoke-CtmApi {
    param([string]$Method, [string]$Url, [object]$Body = $null)

    try {
        if ($Body) {
            $json = $Body | ConvertTo-Json -Depth 10 -Compress
            $resp = Invoke-WebRequest -Uri $Url -Method $Method -Headers $Headers -Body $json -SkipHttpErrorCheck
        } else {
            $resp = Invoke-WebRequest -Uri $Url -Method $Method -Headers $Headers -SkipHttpErrorCheck
        }
        $parsed = $null
        try { $parsed = $resp.Content | ConvertFrom-Json } catch { $parsed = $null }
        return @{ StatusCode = $resp.StatusCode; Body = $parsed; Raw = $resp.Content }
    } catch {
        return @{ StatusCode = -1; Body = $null; Raw = $_.Exception.Message }
    }
}

function Get-CtmConnectionProfile {
    param([string]$CcpName)

    if (-not $CcpName) { return @{ Error = "no connection profile name provided"; HostName = $null; Port = $null; Type = $null } }

    $url = "$BaseUrl/deploy/connectionprofiles/centralized?type=FileTransfer&name=$CcpName"
    $res = Invoke-CtmApi -Method "GET" -Url $url

    if ($res.StatusCode -ne 200) {
        return @{ Error = "CCP lookup failed, status $($res.StatusCode)"; HostName = $null; Port = $null; Type = $null }
    }
    if (-not $res.Body -or -not ($res.Body.PSObject.Properties.Name -contains $CcpName)) {
        return @{ Error = "CCP response did not contain expected key '$CcpName'"; HostName = $null; Port = $null; Type = $null }
    }

    $profile = $res.Body.$CcpName
    $hostName = if ($profile.PSObject.Properties.Name -contains "HostName") { $profile.HostName } else { $null }
    $type     = if ($profile.PSObject.Properties.Name -contains "Type") { $profile.Type } else { $null }

    # Port is only present on the profile when it differs from default - absent means use default
    $port = $null
    if ($profile.PSObject.Properties.Name -contains "Port" -and $profile.Port) {
        $port = [int]$profile.Port
    }

    return @{ Error = $null; HostName = $hostName; Port = $port; Type = $type }
}

function Test-NetworkEndpoint {
    param([string]$HostName, [int]$Port)

    # ICMP ping - note: this only proves the host responds to ping FROM THIS MACHINE.
    # It does NOT confirm the Control-M agent (which performs the real transfer) can
    # reach this host - that path may differ entirely (network segment, firewall, NAT).
    $pingOk = $false
    $pingMessage = ""
    try {
        $pingResult = Test-Connection -TargetName $HostName -Count 1 -Quiet -ErrorAction Stop
        $pingOk = [bool]$pingResult
        $pingMessage = if ($pingOk) { "ICMP reply received" } else { "no ICMP reply" }
    } catch {
        $pingOk = $false
        $pingMessage = "ICMP test error: $($_.Exception.Message)"
    }

    # TCP port-connect - proves the port is open and accepting connections FROM THIS MACHINE.
    # Uses raw TcpClient rather than Test-NetConnection, since Test-NetConnection is part of
    # the Windows-only NetTCPIP module and is NOT available in PS7 on macOS/Linux.
    $portOk = $false
    $portMessage = ""
    try {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $connectTask = $tcpClient.ConnectAsync($HostName, $Port)
        $completed = $connectTask.Wait(3000)  # 3 second timeout
        if ($completed -and $tcpClient.Connected) {
            $portOk = $true
            $portMessage = "TCP port $Port open"
        } else {
            $portOk = $false
            $portMessage = "TCP port $Port closed, filtered, or timed out"
        }
        $tcpClient.Close()
    } catch {
        $portOk = $false
        $portMessage = "Port test error: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Host         = $HostName
        Port         = $Port
        PingOk       = $pingOk
        PingMessage  = $pingMessage
        PortOk       = $portOk
        PortMessage  = $portMessage
    }
}

function Get-FirstHostgroupAgent {
    param([string]$Server, [string]$Hostgroup)

    $url = "$BaseUrl/config/server/$Server/hostgroup/$Hostgroup/agents"
    $res = Invoke-CtmApi -Method "GET" -Url $url

    if ($res.StatusCode -ne 200) {
        return @{ Error = "hostgroup lookup failed, status $($res.StatusCode)"; Agent = $null }
    }
    if (-not $res.Body -or $res.Body.Count -eq 0) {
        return @{ Error = "hostgroup returned empty agent list"; Agent = $null }
    }
    return @{ Error = $null; Agent = $res.Body[0].host }
}

function Test-CtmAgent {
    param([string]$Server, [string]$AgentHost)

    $url = "$BaseUrl/config/server/$Server/agent/$AgentHost/test"
    $res = Invoke-CtmApi -Method "POST" -Url $url -Body @{ parameters = @() }

    $message = $null
    if ($res.Body) {
        if ($res.Body.PSObject.Properties.Name -contains "message") { $message = $res.Body.message }
        elseif ($res.Body.PSObject.Properties.Name -contains "errors" -and $res.Body.errors.Count -gt 0) { $message = $res.Body.errors[0].message }
    }
    if (-not $message) { $message = "status $($res.StatusCode), no message field" }

    return @{ Ok = ($res.StatusCode -eq 200); Message = $message }
}

function Test-CtmConnectionProfile {
    param([string]$Server, [string]$AgentHost, [string]$CcpType, [string]$CcpName)

    if (-not $CcpName) {
        return @{ Skipped = $true; Reason = "no connection profile name on job" }
    }

    $url = "$BaseUrl/deploy/connectionprofile/centralized/test/$CcpType/$CcpName/$Server/$AgentHost"
    $res = Invoke-CtmApi -Method "POST" -Url $url

    $message = $null
    if ($res.Body) {
        if ($res.Body.PSObject.Properties.Name -contains "message") { $message = $res.Body.message }
        elseif ($res.Body.PSObject.Properties.Name -contains "errors" -and $res.Body.errors.Count -gt 0) { $message = $res.Body.errors[0].message }
    }
    if (-not $message) { $message = "status $($res.StatusCode), no message field" }

    $lower = $message.ToLower()
    $ok = $false
    if ($lower.StartsWith("error")) { $ok = $false }
    elseif ($lower.Contains("successfully")) { $ok = $true }

    return @{ Skipped = $false; Ok = $ok; Message = $message }
}

# ---------------------------------------------------------------------------
# Memoization caches - populated on first call, reused silently on subsequent
# identical requests within the same run. Eliminates redundant API calls when
# multiple jobs share the same hostgroup, agent, connection profile, or endpoint.
# ---------------------------------------------------------------------------
$cacheHostgroupAgent  = @{}   # key: "$Server|$Hostgroup"       → @{Error;Agent}
$cacheAgentTest       = @{}   # key: "$Server|$AgentHost"        → @{Ok;Message}
$cacheCcpTest         = @{}   # key: "$CcpName|$AgentHost"       → @{Skipped;Ok;Message;Reason}
$cacheCcpProfile      = @{}   # key: "$CcpName"                  → @{Error;HostName;Port;Type}
$cacheNetEndpoint     = @{}   # key: "$HostName|$Port"           → @{PingOk;PingMessage;PortOk;PortMessage}

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------
if ($Output -eq "verbose") {
    Write-ColorText "=== CTM Engineer Demo: Folder `"$Folder`" on server `"$Server`" ===" Cyan
}

$jobsUrl = "$BaseUrl/deploy/jobs?format=json&folder=$Folder&server=$Server&useArrayFormat=true"
$jobsRes = Invoke-CtmApi -Method "GET" -Url $jobsUrl

if ($jobsRes.StatusCode -ne 200) {
    Write-ColorText "Failed to retrieve jobs for folder '$Folder': status $($jobsRes.StatusCode)" Red
    Write-Host $jobsRes.Raw
    exit 1
}

$allJobs = Get-AllJobs -Node $jobsRes.Body -ParentName "Root"
if ($Output -eq "verbose") {
    Write-Host "Found $($allJobs.Count) job(s) across all types.`n"
}

$jobResults = @()

foreach ($job in $allJobs) {
    $hostLabel = if ($job.Host) { $job.Host } else { "none" }
    if ($Output -eq "verbose") {
        Write-Host "Job `"$($job.Name)`" [$($job.Type)] (Host/Hostgroup: $hostLabel)"
    }

    $testedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $result = [PSCustomObject]@{
        Job              = $job.Name
        Type             = ($job.Type -replace "^Job:", "")
        Hostgroup        = $job.Host
        Agent            = $null
        AgentStatus      = "SKIPPED"
        AgentMessage     = "no Host field on this job type"
        CcpSrcName       = $job.ConnectionProfileSrc
        CcpSrcStatus     = "SKIPPED"
        CcpSrcMessage    = ""
        CcpDestName      = $job.ConnectionProfileDest
        CcpDestStatus    = "SKIPPED"
        CcpDestMessage   = ""
        NetSrcHost       = ""
        NetSrcPingStatus = "SKIPPED"
        NetSrcPortStatus = "SKIPPED"
        NetSrcNote       = ""
        NetDestHost      = ""
        NetDestPingStatus = "SKIPPED"
        NetDestPortStatus = "SKIPPED"
        NetDestNote      = ""
        TestedAt         = $testedAt
    }

    if (-not $job.Host) {
        if ($Output -eq "verbose") { Write-ColorText "  Skipping - job has no Host/Hostgroup defined" Yellow }
        $jobResults += $result
        continue
    }

    $hgKey = "$Server|$($job.Host)"
    if ($cacheHostgroupAgent.ContainsKey($hgKey)) {
        $hg = $cacheHostgroupAgent[$hgKey]
    } else {
        $hg = Get-FirstHostgroupAgent -Server $Server -Hostgroup $job.Host
        $cacheHostgroupAgent[$hgKey] = $hg
    }
    if ($hg.Error) {
        if ($Output -eq "verbose") { Write-ColorText "  [ERROR] $($hg.Error)" Red }
        $result.AgentStatus = "ERROR"
        $result.AgentMessage = "HOSTGROUP LOOKUP FAILED: $($hg.Error)"
        $jobResults += $result
        continue
    }
    $result.Agent = $hg.Agent

    $agentKey = "$Server|$($hg.Agent)"
    if ($cacheAgentTest.ContainsKey($agentKey)) {
        $agentTest = $cacheAgentTest[$agentKey]
    } else {
        $agentTest = Test-CtmAgent -Server $Server -AgentHost $hg.Agent
        $cacheAgentTest[$agentKey] = $agentTest
    }
    $result.AgentStatus = if ($agentTest.Ok) { "OK" } else { "ERROR" }
    $result.AgentMessage = $agentTest.Message
    $agentColor = if ($agentTest.Ok) { "Green" } else { "Red" }
    if ($Output -eq "verbose") {
        Write-ColorText "  Agent: $($hg.Agent) | $(if ($agentTest.Ok) { 'OK' } else { 'FAIL' }) | $($agentTest.Message)" $agentColor
    }

    if ($job.Type -ne "Job:FileTransfer") {
        if ($Output -eq "verbose") { Write-ColorText "  No CCP test - job type is $($job.Type), not Job:FileTransfer" DarkGray }
        $jobResults += $result
        continue
    }

    if (-not $agentTest.Ok) {
        if ($Output -eq "verbose") { Write-ColorText "  Skipping CCP tests - agent not reachable" Yellow }
        $jobResults += $result
        continue
    }

    $srcCcpKey = "$($job.ConnectionProfileSrc)|$($hg.Agent)"
    if ($cacheCcpTest.ContainsKey($srcCcpKey)) {
        $srcTest = $cacheCcpTest[$srcCcpKey]
    } else {
        $srcTest = Test-CtmConnectionProfile -Server $Server -AgentHost $hg.Agent -CcpType $CcpType -CcpName $job.ConnectionProfileSrc
        $cacheCcpTest[$srcCcpKey] = $srcTest
    }
    $result.CcpSrcStatus = if ($srcTest.Skipped) { "SKIPPED" } elseif ($srcTest.Ok) { "OK" } else { "ERROR" }
    $result.CcpSrcMessage = if ($srcTest.Skipped) { $srcTest.Reason } else { $srcTest.Message }
    $srcLabel = if ($srcTest.Skipped) { "SKIPPED" } elseif ($srcTest.Ok) { "OK" } else { "FAIL" }
    $srcColor = if ($srcTest.Skipped) { "Yellow" } elseif ($srcTest.Ok) { "Green" } else { "Red" }
    if ($Output -eq "verbose") {
        Write-ColorText "  CCP Src  ($($job.ConnectionProfileSrc)): $srcLabel | $($result.CcpSrcMessage)" $srcColor
    }

    $destCcpKey = "$($job.ConnectionProfileDest)|$($hg.Agent)"
    if ($cacheCcpTest.ContainsKey($destCcpKey)) {
        $destTest = $cacheCcpTest[$destCcpKey]
    } else {
        $destTest = Test-CtmConnectionProfile -Server $Server -AgentHost $hg.Agent -CcpType $CcpType -CcpName $job.ConnectionProfileDest
        $cacheCcpTest[$destCcpKey] = $destTest
    }
    $result.CcpDestStatus = if ($destTest.Skipped) { "SKIPPED" } elseif ($destTest.Ok) { "OK" } else { "ERROR" }
    $result.CcpDestMessage = if ($destTest.Skipped) { $destTest.Reason } else { $destTest.Message }
    $destLabel = if ($destTest.Skipped) { "SKIPPED" } elseif ($destTest.Ok) { "OK" } else { "FAIL" }
    $destColor = if ($destTest.Skipped) { "Yellow" } elseif ($destTest.Ok) { "Green" } else { "Red" }
    if ($Output -eq "verbose") {
        Write-ColorText "  CCP Dest ($($job.ConnectionProfileDest)): $destLabel | $($result.CcpDestMessage)" $destColor
    }

    # ---- Network reachability test (SFTP-type connection profiles only) ----
    # Host and port are resolved from the connection profile itself via the CCP endpoint,
    # not from job Variables - this is the authoritative source per BMC's own API.
    # This is a GLOBAL CHECK from THIS MACHINE, not from the Control-M agent.
    if ($cacheCcpProfile.ContainsKey($job.ConnectionProfileSrc)) {
        $srcProfile = $cacheCcpProfile[$job.ConnectionProfileSrc]
    } else {
        $srcProfile = Get-CtmConnectionProfile -CcpName $job.ConnectionProfileSrc
        $cacheCcpProfile[$job.ConnectionProfileSrc] = $srcProfile
    }
    if (-not $srcProfile.Error -and $srcProfile.Type -and $srcProfile.Type -like "*SFTP*" -and $srcProfile.HostName) {
        $srcPort = if ($srcProfile.Port) { $srcProfile.Port } else { $SftpPort }
        $result.NetSrcHost = $srcProfile.HostName
        $netSrcKey = "$($srcProfile.HostName)|$srcPort"
        if ($cacheNetEndpoint.ContainsKey($netSrcKey)) {
            $netSrc = $cacheNetEndpoint[$netSrcKey]
        } else {
            $netSrc = Test-NetworkEndpoint -HostName $srcProfile.HostName -Port $srcPort
            $cacheNetEndpoint[$netSrcKey] = $netSrc
        }
        $result.NetSrcPingStatus = if ($netSrc.PingOk) { "OK" } else { "FAIL" }
        $result.NetSrcPortStatus = if ($netSrc.PortOk) { "OK" } else { "FAIL" }
        $result.NetSrcNote = "GLOBAL CHECK ONLY (from this machine, not the agent) - port $srcPort$(if (-not $srcProfile.Port) { ' (default)' }) - $($netSrc.PingMessage); $($netSrc.PortMessage)"
        $srcPingColor = if ($netSrc.PingOk) { "Green" } else { "Red" }
        $srcPortColor = if ($netSrc.PortOk) { "Green" } else { "Red" }
        if ($Output -eq "verbose") {
            Write-ColorText "  Net Src  ($($srcProfile.HostName):$srcPort) [GLOBAL CHECK ONLY] Ping: $($netSrc.PingMessage)" $srcPingColor
            Write-ColorText "  Net Src  ($($srcProfile.HostName):$srcPort) [GLOBAL CHECK ONLY] Port: $($netSrc.PortMessage)" $srcPortColor
        }
    }

    if ($cacheCcpProfile.ContainsKey($job.ConnectionProfileDest)) {
        $destProfile = $cacheCcpProfile[$job.ConnectionProfileDest]
    } else {
        $destProfile = Get-CtmConnectionProfile -CcpName $job.ConnectionProfileDest
        $cacheCcpProfile[$job.ConnectionProfileDest] = $destProfile
    }
    if (-not $destProfile.Error -and $destProfile.Type -and $destProfile.Type -like "*SFTP*" -and $destProfile.HostName) {
        $destPort = if ($destProfile.Port) { $destProfile.Port } else { $SftpPort }
        $result.NetDestHost = $destProfile.HostName
        $netDestKey = "$($destProfile.HostName)|$destPort"
        if ($cacheNetEndpoint.ContainsKey($netDestKey)) {
            $netDest = $cacheNetEndpoint[$netDestKey]
        } else {
            $netDest = Test-NetworkEndpoint -HostName $destProfile.HostName -Port $destPort
            $cacheNetEndpoint[$netDestKey] = $netDest
        }
        $result.NetDestPingStatus = if ($netDest.PingOk) { "OK" } else { "FAIL" }
        $result.NetDestPortStatus = if ($netDest.PortOk) { "OK" } else { "FAIL" }
        $result.NetDestNote = "GLOBAL CHECK ONLY (from this machine, not the agent) - port $destPort$(if (-not $destProfile.Port) { ' (default)' }) - $($netDest.PingMessage); $($netDest.PortMessage)"
        $destPingColor = if ($netDest.PingOk) { "Green" } else { "Red" }
        $destPortColor = if ($netDest.PortOk) { "Green" } else { "Red" }
        if ($Output -eq "verbose") {
            Write-ColorText "  Net Dest ($($destProfile.HostName):$destPort) [GLOBAL CHECK ONLY] Ping: $($netDest.PingMessage)" $destPingColor
            Write-ColorText "  Net Dest ($($destProfile.HostName):$destPort) [GLOBAL CHECK ONLY] Port: $($netDest.PortMessage)" $destPortColor
        }
    }

    $jobResults += $result
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$totalJobs = $jobResults.Count
$agentTestable = $jobResults | Where-Object { $_.AgentStatus -ne "SKIPPED" }
$agentFailures = $agentTestable | Where-Object { $_.AgentStatus -eq "ERROR" }
$ccpFailures = $jobResults | Where-Object {
    $_.CcpSrcStatus -eq "ERROR" -or $_.CcpDestStatus -eq "ERROR"
}
$fileTransferCount = ($jobResults | Where-Object { $_.Type -eq "FileTransfer" }).Count
$netTested = $jobResults | Where-Object { $_.NetSrcHost -or $_.NetDestHost }
$netFailures = $netTested | Where-Object {
    $_.NetSrcPingStatus -eq "FAIL" -or $_.NetSrcPortStatus -eq "FAIL" -or
    $_.NetDestPingStatus -eq "FAIL" -or $_.NetDestPortStatus -eq "FAIL"
}

if ($Output -eq "verbose") {
    Write-ColorText "`n=== SUMMARY ===" Cyan
    Write-Host "Total jobs: $totalJobs | Agent-testable: $($agentTestable.Count) | Agent failures: $($agentFailures.Count) | CCP failures: $($ccpFailures.Count)"

    if ($agentFailures.Count -gt 0) {
        Write-ColorText "Agent failures:" Red
        $agentFailures | ForEach-Object { Write-ColorText "  - $($_.Job) (agent $($_.Agent)): $($_.AgentMessage)" Red }
    }
    if ($ccpFailures.Count -gt 0) {
        Write-ColorText "CCP failures:" Red
        $ccpFailures | ForEach-Object {
            if ($_.CcpSrcStatus -eq "ERROR") { Write-ColorText "  - $($_.Job) SRC ($($_.Hostgroup)): $($_.CcpSrcMessage)" Red }
            if ($_.CcpDestStatus -eq "ERROR") { Write-ColorText "  - $($_.Job) DEST ($($_.Hostgroup)): $($_.CcpDestMessage)" Red }
        }
    }

    # ---------------------------------------------------------------------------
    # Color-coded table
    # ---------------------------------------------------------------------------
    Write-ColorText "`n=== REPORT: $Folder on $Server ===" Cyan
    $agentSummaryColor = if ($agentFailures.Count -eq 0) { "Green" } else { "Red" }
    $ccpSummaryColor = if ($ccpFailures.Count -eq 0) { "Green" } else { "Red" }
    Write-ColorText "Agents: $($agentTestable.Count - $agentFailures.Count)/$($agentTestable.Count) reachable" $agentSummaryColor
    Write-ColorText "Connection profiles: $($fileTransferCount * 2 - $ccpFailures.Count)/$($fileTransferCount * 2) valid" $ccpSummaryColor
    if ($netTested.Count -gt 0) {
        $netSummaryColor = if ($netFailures.Count -eq 0) { "Green" } else { "Red" }
        Write-ColorText "SFTP endpoints tested: $($netTested.Count - $netFailures.Count)/$($netTested.Count) fully reachable" $netSummaryColor
        Write-ColorText ""
        Write-ColorText "*****************************************************************************" Yellow
        Write-ColorText "* NOTE: SFTP ping/port checks are GLOBAL CHECKS run FROM THIS MACHINE.        *" Yellow
        Write-ColorText "* They do NOT confirm the Control-M agent itself can reach these hosts -      *" Yellow
        Write-ColorText "* the agent's network path (segment, firewall, NAT) may differ entirely.      *" Yellow
        Write-ColorText "*****************************************************************************" Yellow
    }
    Write-Host ""

    $rowFormat = "{0,-28} {1,-16} {2,-14} {3,-26} "
    Write-Host ($rowFormat -f "Job", "Type", "Hostgroup", "Agent") -NoNewline
    $badgeHeaderFormat = (0..4 | ForEach-Object { "{$_,-$BadgeColumnWidth}" }) -join ""
    Write-Host ($badgeHeaderFormat -f "AgentTest", "CcpSrc", "CcpDest", "NetSrc", "NetDest")

    foreach ($r in $jobResults) {
        Write-Host ($rowFormat -f $r.Job, $r.Type, $r.Hostgroup, $r.Agent) -NoNewline

        switch ($r.AgentStatus) {
            "SKIPPED" { Write-Badge -Text "SKIP" -State "warn" }
            "OK"      { Write-Badge -Text "OK  " -State "ok" }
            default   { Write-Badge -Text "FAIL" -State "error" }
        }
        switch ($r.CcpSrcStatus) {
            "SKIPPED" { Write-Badge -Text "SKIP" -State "warn" }
            "OK"      { Write-Badge -Text "OK  " -State "ok" }
            default   { Write-Badge -Text "FAIL" -State "error" }
        }
        switch ($r.CcpDestStatus) {
            "SKIPPED" { Write-Badge -Text "SKIP" -State "warn" }
            "OK"      { Write-Badge -Text "OK  " -State "ok" }
            default   { Write-Badge -Text "FAIL" -State "error" }
        }

        # NetSrc: combined ping+port badge - SKIP if not tested, else FAIL if either signal failed
        if (-not $r.NetSrcHost) { Write-Badge -Text "SKIP" -State "warn" }
        elseif ($r.NetSrcPingStatus -eq "OK" -and $r.NetSrcPortStatus -eq "OK") { Write-Badge -Text "OK  " -State "ok" }
        else { Write-Badge -Text "FAIL" -State "error" }

        if (-not $r.NetDestHost) { Write-Badge -Text "SKIP" -State "warn" }
        elseif ($r.NetDestPingStatus -eq "OK" -and $r.NetDestPortStatus -eq "OK") { Write-Badge -Text "OK  " -State "ok" }
        else { Write-Badge -Text "FAIL" -State "error" }

        Write-Host ""
    }

    # ---------------------------------------------------------------------------
    # Unique resources summary
    # ---------------------------------------------------------------------------
    Write-ColorText "`n=== UNIQUE RESOURCES TESTED ===" Cyan

    Write-ColorText "`nHostgroups ($($cacheHostgroupAgent.Count) unique):" Cyan
    $cacheHostgroupAgent.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $key = $_.Name.Split("|")[1]
        if ($_.Value.Error) {
            Write-ColorText "  $key  →  ERROR: $($_.Value.Error)" Red
        } else {
            Write-ColorText "  $key  →  $($_.Value.Agent)" Green
        }
    }

    Write-ColorText "`nAgents ($($cacheAgentTest.Count) unique):" Cyan
    $cacheAgentTest.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $key = $_.Name.Split("|")[1]
        if ($_.Value.Ok) {
            Write-ColorText "  $key  →  OK" Green
        } else {
            Write-ColorText "  $key  →  FAIL: $($_.Value.Message)" Red
        }
    }

    Write-ColorText "`nConnection profiles tested ($($cacheCcpTest.Count) unique combinations):" Cyan
    $cacheCcpTest.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $parts = $_.Name.Split("|")
        $ccpName = $parts[0]; $agent = $parts[1]
        if ($_.Value.Skipped) {
            Write-ColorText "  $ccpName on $agent  →  SKIPPED" Yellow
        } elseif ($_.Value.Ok) {
            Write-ColorText "  $ccpName on $agent  →  OK" Green
        } else {
            Write-ColorText "  $ccpName on $agent  →  FAIL: $($_.Value.Message)" Red
        }
    }

    Write-ColorText "`nConnection profile metadata ($($cacheCcpProfile.Count) unique):" Cyan
    $cacheCcpProfile.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $prof = $_.Value
        if ($prof.Error) {
            # Distinguish a genuine API error from a non-SFTP profile that simply has no HostName
            if ($prof.Error -like "*did not contain expected key*") {
                Write-ColorText "  $($_.Name)  →  SKIPPED (non-SFTP profile, no network endpoint)" Yellow
            } else {
                Write-ColorText "  $($_.Name)  →  ERROR: $($prof.Error)" Red
            }
        } else {
            $typeShort = $prof.Type -replace "^ConnectionProfile:FileTransfer:", ""
            if ($typeShort -like "*SFTP*") {
                $portLabel = if ($prof.Port) { ":$($prof.Port)" } else { ":$SftpPort (default)" }
                Write-ColorText "  $($_.Name)  →  $typeShort  $($prof.HostName)$portLabel" Green
            } else {
                Write-ColorText "  $($_.Name)  →  $typeShort (no network endpoint to test)" Yellow
            }
        }
    }

    if ($cacheNetEndpoint.Count -gt 0) {
        Write-ColorText "`nNetwork endpoints tested ($($cacheNetEndpoint.Count) unique) [GLOBAL CHECK ONLY]:" Cyan
        $cacheNetEndpoint.GetEnumerator() | Sort-Object Name | ForEach-Object {
            $parts = $_.Name.Split("|")
            $endpointHost = $parts[0]; $endpointPort = $parts[1]
            $pingLabel = if ($_.Value.PingOk) { "Ping OK" } else { "Ping FAIL" }
            $portLabel = if ($_.Value.PortOk) { "Port $endpointPort OK" } else { "Port $endpointPort FAIL" }
            $color = if ($_.Value.PingOk -and $_.Value.PortOk) { "Green" } else { "Red" }
            Write-ColorText "  ${endpointHost}:${endpointPort}  →  $pingLabel  |  $portLabel" $color
        }
    }
}

# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------
$runTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$runStamp     = Get-Date -Format "yyyyMMdd_HHmmss"

$summaryObject = [PSCustomObject]@{
    Folder              = $Folder
    Server              = $Server
    RunTimestamp        = $runTimestamp
    TotalJobs           = $totalJobs
    AgentTestableJobs   = $agentTestable.Count
    AgentFailures       = $agentFailures.Count
    CcpFailures         = $ccpFailures.Count
    NetEndpointsTested  = $netTested.Count
    NetEndpointFailures = $netFailures.Count
    NetTestDisclaimer   = "SFTP ping/port checks are GLOBAL CHECKS run from the machine executing this script. They do NOT confirm the Control-M agent itself can reach these hosts - the agent's network path may differ entirely."
    Jobs                = $jobResults
}

$jsonPath = Join-Path $LogFolder "ctm_preflight_${Folder}_${runStamp}.json"
$jsonContent = $summaryObject | ConvertTo-Json -Depth 6
$jsonContent | Out-File -FilePath $jsonPath -Encoding utf8

switch ($Output) {
    "verbose" { Write-ColorText "`nJSON report: $jsonPath" Cyan }
    "json"    { Write-Output $jsonContent }
    "file"    { Write-Output $jsonPath }
}

# Exit code reflects overall pass/fail for CI/demo scripting use
if ($agentFailures.Count -gt 0 -or $ccpFailures.Count -gt 0) {
    exit 1
}
exit 0