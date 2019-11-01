# Scripts and Documentation

This directory contains 1 example script:
* [get_report.sh](./get_report.sh)

The script demonstrates using a bash script in conjunction with curl to connect to Control-M Automation API to generate and retrieve the specified report.


### Adjust script retry as needed.  The default allows for 2 minutes.
```
maxiterations=12    # number of iterations the script will check if jobs are still running
sleepinterval=10    # number of seconds between each interval
```
### Logout function
A logout function is defined which can be easily called before any `exit` call
made in the script. This is to make the code more readable.
```
curl -k -s -H "Authorization: Bearer $token" -X POST "$endpoint/session/logout"
```


### Check report format
Check for 'pdf' or 'csv'.  Although the default is 'csv' when left blank when not specified the API request fails.
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
getReportID=$(curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X POST -d "{\"name\": \"${reportName}\", \"format\": \"${reportFormat}\"}" "$endpoint/reporting/report")
```
### Get Report ID
```
if [[ $getReportID == *reportId* ]]; then
   reportID=$(echo ${getReportID##*reportId\" : \"} | cut -d '"' -f 1)
```

### Check report status until "SUCCEEDED" and get report URL
```
until [[ $reportStatus == "SUCCEEDED" || $i>=$maxiterations ]]; do
   sleep $sleepinterval
   getReportStatus=$(curl -k -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -X GET "$endpoint/reporting/status/$reportID")
   ...
   reportURL=$(echo ${getReportStatus##*url\" : \"} | cut -d '"' -f 1)
```

### Download Report
```
wget --no-check-certificate --directory-prefix=${outputDirectory} "${reportURL}"
```
wget is executed with the --no-check-certificate switch which allows insecure server connections when using SSL.  This switch can be removed if trusted cerficates are
installed for Control-M/Enterpirse Manager.

### Sample Execution
```
./get_report.sh -e https://wla919:8443/automation-api -u reportuser -p reportuserpassword -r active_jobs -f pdf
Submitting report active_jobs
reportID=3077df4c-1a21-475e-bf74-3b9efe9dba30
Checking report status.  Please wait.
...
status=SUCCEEDED
reportURL:http://wla919:18080/RF-Server-Files/3077df4c-1a21-475e-bf74-3b9efe9dba30.pdf
Downloading report.  Please wait.
--2019-08-16 16:17:30--  http://wla919:18080/RF-Server-Files/3077df4c-1a21-475e-bf74-3b9efe9dba30.pdf
Resolving wla919 (wla919)... 172.28.198.9
Connecting to wla919 (wla919)|172.28.198.9|:18080... connected.
HTTP request sent, awaiting response... 200
Length: 2729 (2.7K) [application/pdf]
Saving to: ‘3077df4c-1a21-475e-bf74-3b9efe9dba30.pdf’

100%[==============================================================================================================================================>] 2,729       --.-K/s   in 0.006s

2019-08-16 16:17:30 (413 KB/s) - ‘3077df4c-1a21-475e-bf74-3b9efe9dba30.pdf’ saved [2729/2729]
```


