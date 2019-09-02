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

### Sample Execution
```
$ ./get_report.sh -e https://wla919:8443/automation-api -u reportuser -p reportuserpassword -r active_jobs -f pdf
Submitting report active_jobs
reportID=bea8d191-d2b8-4cb3-be25-12db00eb6257
.
status=SUCCEEDED
reportURL:http://wla919:18080/RF-Server-Files/bea8d191-d2b8-4cb3-be25-12db00eb6257.pdf
--2019-07-31 17:45:35--  http://wla919:18080/RF-Server-Files/bea8d191-d2b8-4cb3-be25-12db00eb6257.pdf
Resolving wla919 (wla919)... 172.28.197.63
Connecting to wla919 (wla919)|172.28.197.63|:18080... connected.
HTTP request sent, awaiting response... 200
Length: 2728 (2.7K) [application/pdf]
Saving to: ‘bea8d191-d2b8-4cb3-be25-12db00eb6257.pdf’

100%[=================================================================================================================================================================>] 2,728       --.-K/s   in 0.006s

2019-07-31 17:45:35 (456 KB/s) - ‘bea8d191-d2b8-4cb3-be25-12db00eb6257.pdf’ saved [2728/2728]
```


