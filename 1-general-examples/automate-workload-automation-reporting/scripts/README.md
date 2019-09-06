# Scripts & Documentation

This directory contains 1 example script:
* [report_get_curl.sh](./report_get_curl.sh)

The script demonstrates using a bash script in conjunction with curl to connect to Control-M Automation API to genereate and retrieve the specified report.

### Logout function
A logout function is defined which can be easily called before any `exit` call
made in the script. This is to make the code more readable.
```
curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"
```


### URL encode report name
This is needed to convert spaces to %20 to enable use of the filename in a URL
```
reportName=$(echo $reportName | sed 's/ /%20/g')
```

### Check report format
Check for 'pdf' or 'csv'.  Although the default is 'csv' when left blank when not specifed the API request fails.
```
# Check report format
case $reportFormat in
   pdf|PDF)

```

### Check for switches and options
For the -o switch, specify the output directory. Otherwise the default is the current working directory.
```
outputDirectory=""
while getopts ":e:u:p:r:f:o:" opt; do
```

### Check if curl is available
```
getCurlVersion=$(curl --version)
if [[ ${getCurlVersion} == *Release-Date* ]]; then
```
curl is executed with the -k switch which allows insecure server connections when using SSL.  This switch can be removed if trusted cerficates are 
installed for Control-M/Enterpirse Manager.

### Login
First, a login to Control-M is performed, and the session token is captured:
```
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
if [[ $login == *token* ]] ; then
	token=$(echo ${login##*token\" : \"} | cut -d '"' -f 1)
```

The session token is needed for all subsequent calls to Control-M.

### Generate Report
```
getReportURL=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/reporting/report/${reportName}?format=${reportFormat}")
```

### Download Report
```
wget --no-check-certificate --directory-prefix=${outputDirectory} "${reportURL}"
```
wget is executed with the --no-check-certificate switch which allows insecure server connections when using SSL.  This switch can be removed if trusted cerficates are 
installed for Control-M/Enterpirse Manager.

### Sample Execution
```
./report_get_curl.sh  -e https://wla919:8443/automation-api -u reportuser -p reportuserpassword -r "active_jobs" -o /tmp -f pdf
Generating report.  Please wait...
reportURL=http://wla919:18080/RF-Server-Files/9e837d78-b50d-4e6a-80d0-c8424b22f480.pdf
Downloading report.  Please wait...
--2019-08-12 16:21:46--  http://wla919:18080/RF-Server-Files/9e837d78-b50d-4e6a-80d0-c8424b22f480.pdf
Resolving wla919 (wla919)... 172.28.196.77
Connecting to wla919 (wla919)|172.28.196.77|:18080... connected.
HTTP request sent, awaiting response... 200
Length: 2729 (2.7K) [application/pdf]
Saving to: ‘/tmp/9e837d78-b50d-4e6a-80d0-c8424b22f480.pdf’

100%[==============================================================================================================================================>] 2,729       --.-K/s   in 0s

2019-08-12 16:21:47 (190 MB/s) - ‘/tmp/9e837d78-b50d-4e6a-80d0-c8424b22f480.pdf’ saved [2729/2729]

```

