
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"

Invoke-WebRequest -SkipCertificateCheck -Uri "https://ec2-52-32-170-215.us-west-2.compute.amazonaws.com:8443/automation-api/ctm-cli.tgz" -Outfile ctm-cli.tgz