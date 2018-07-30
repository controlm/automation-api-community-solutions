# Get job status using curl 
This script can be used to get the Control-M job status in json format. The output can be used to feed external applications e.g. a dashboard.


## Usage

    get_job_status <endpoint> <username> <password> <application> <outputfile>

Parameter|Comment
---------|-------
endpoint|https://<hostname>:8443/automation-api
user|Control-M user name
password|Control-M password
application|name of the application or "*"
outputfile|file to store the output (optional)

__note:__ Put * in double quotes to get all applications. 
