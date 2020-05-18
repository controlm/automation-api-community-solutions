function Env-Update {
    foreach($level in "Machine","User") {
       [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
          # For Path variables, append the new values, if they're not already in there
          if($_.Name -match 'Path$') { 
             $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
          }
          $_
       } | Set-Content -Path { "Env:$($_.Name)" }
    }
}

for ( $i = 0; $i -lt $args.count; $i++ ) {
    write-host "Argument  $i is $($args[$i])"
}


#----------------------------------------------------------------------------------------
# Create the Powershell script to finish setup
#
#   The code below is not executed here. It's written to a file that is then executed 
#   at the very end of this script via "pwsh <filenmae>
#----------------------------------------------------------------------------------------
$code = @' 

function Env-Update {
    foreach($level in "Machine","User") {
       [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
          # For Path variables, append the new values, if they're not already in there
          if($_.Name -match 'Path$') { 
             $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
          }
          $_
       } | Set-Content -Path { "Env:$($_.Name)" }
    }
}

for ( $i = 0; $i -lt $args.count; $i++ ) {
    write-host "Argument  $i is $($args[$i])"
}

# Download node.js installer
Invoke-WebRequest -SkipCertificateCheck -UseBasicParsing -Uri "https://nodejs.org/dist/v12.16.1/node-v12.16.1-x64.msi" -Outfile nodejs.msi

# Install node.js
Start-Process "msiexec.exe" -ArgumentList '/I nodejs.msi /quiet' -Wait -NoNewWindow
Env-Update

# Download ctm cli
Invoke-WebRequest -SkipCertificateCheck -UseBasicParsing -Uri "https://ec2-52-32-170-215.us-west-2.compute.amazonaws.com:8443/automation-api/ctm-cli.tgz" -Outfile ctm-cli.tgz

Invoke-Expression -Command:'cmd.exe /c npm install -g ctm-cli.tgz'
Env-Update

Invoke-WebRequest -UseBasicParsing -Uri "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=241505_1f5b5a70bf22433b84d0e960903adac8" -Outfile Java8Setup.exe
# Install Java silently maybe /s ??
./Java8Setup.exe INSTALL_SILENT=Enable

[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files (x86)\Java\jre.8.0.241", "Machine")

Invoke-Expression -Command:'cmd.exe /c ctm env add ctmenv https://ec2-52-32-170-215.us-west-2.compute.amazonaws.com:8443/automation-api/ apiuser 2Mzpah7msYUA94ZyzPztqBrn'

'@

# Create file:

$code | Out-File 'setupScriptPart2.ps1'

#----------------------------------------------------------------------------------------
# End of script creation 
#----------------------------------------------------------------------------------------

# Upgrade to latest Powershell to get support for SkipCertificateCheck functionality
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"

Env-Update

pwsh ./setupScriptPart2.ps1
