# scripts

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
reportName=$(echo $1 | sed 's/ /%20/g')
```

### Check report format
Check for 'pdf' or 'csv'.  Although the default is 'csv' when left blank when not specifed the API request fails.
```
reportFormat=""
case $2 in
```

### Check for swithes
This is mainly checking for the -o switch to specify the output directory. Otherwise the default is the current working directory.
```
outputDirectory=""
while getopts ":o:" opt; do
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
getReportURL=$(curl -k -s -H "Authorization: Bearer $token" "$endpoint/reporting/report/${reportName}?format=${reportFormat}")
```

### Download Report
```
wget --no-check-certificate --directory-prefix=${outputDirectory} "${reportURL}"
```




