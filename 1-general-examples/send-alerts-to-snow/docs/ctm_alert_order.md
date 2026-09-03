
# Step 0: Alert

=== Control-M -> Alerting and Incident Pipeline : Start ===

``` json
{
  "call_type": "I",
  "alert_id": "2419",
  "data_center": "ctm-lin-srv",
  "memname": "zzm.pre.flight.sh",
  "order_id": "003i7",
  "severity": "V",
  "status": "Not_Noticed",
  "send_time": "20260814235520",
  "last_user": "",
  "last_time": "",
  "message": "Ended not OK",
  "run_as": "mftuser",
  "sub_application": "Multipath Cloud Demo for %%ZZM_USER_ID",
  "application": "ZZM %%ZZM_COMPANY",
  "job_name": "ZZM PreFlight Check",
  "host_id": "ctm-lin-agt.werkstatt.local",
  "alert_type": "R",
  "closed_from_em": "",
  "ticket_number": "",
  "run_counter": "00002",
  "notes": ""
}
```

# Step 1: Get Job Status

URL: {{baseUrl}}/run/job/:jobId/status
jobId = "${data_center}:${order_id}"

example: "jobId": "ctm-lin-srv:003i7"

Sample Response:

``` json
{
    "jobId": "ctm-lin-srv:003i7",
    "folderId": "ctm-lin-srv:003hh",
    "numberOfRuns": 3,
    "name": "ZZM PreFlight Check",
    "folder": "ZZM_UC_MULTIPATH_CLOUD",
    "type": "Job",
    "status": "Ended Not OK",
    "held": false,
    "deleted": false,
    "cyclic": false,
    "startTime": "20260814235859",
    "endTime": "20260814235859",
    "estimatedStartTime": [
        "20260815000330"
    ],
    "estimatedEndTime": [
        "20260815000830"
    ],
    "orderDate": "260814",
    "ctm": "ctm-lin-srv",
    "description": "PreFlight Check for Use Case",
    "host": "ctm-lin-agt.werkstatt.local",
    "application": "ZZM %%ZZM_COMPANY",
    "subApplication": "Multipath Cloud Demo for %%ZZM_USER_ID",
    "outputURI": "https://ctm.werkstatt.local/automation-api/run/job/ctm-lin-srv:003i7/output",
    "logURI": "https://ctm.werkstatt.local/automation-api/run/job/ctm-lin-srv:003i7/log"
}
```

# Step 2: Get Job Output

URL: {{baseUrl}}/run/job/:jobId/output?runNo=0
runNo = "${run_counter}

example: "runNo": "3"

## Note

- whatch out for **run_counter** to get the right job output
- remove leading **0**, example "00001" = "1"

Sample Response:

``` text
20260814235859Failedtosubmitjob.
20260814235859Foundemptysysoutfile.
20260814235859Possiblecauseofproblem: 
Jobsubmissionabortedduetoerrorinexecuting'/bin/su'.
login.STDOUT-->>
login.STDERR-->>
-bash: line1: /opt/ctmag/ctm/sysout/zzm_pre_flight_sh.LOG_0003i7_00003: Permissiondenied
```


# Step 3: Get Job Log

URL: {{baseUrl}}/run/job/:jobId/log

## Note
 
the job log contains info from all runs.
Im the GUI we see a table:

| Time | Code | Message |
| ---- | ---- | ---- |
| 8/14/2026, 11:37:38 PM | 5065 | Run with date of 20260814 |
| ... | | |
| 8/14/2026, 11:58:59 PM | 5404 | Rerun by user emuser |
| ... | | |

The JSON response from the API looks different.

Sample Response:

``` text
EventTimeMessageCode

23: 37: 3814-Aug-2026RUNJOB: 1769;DAILYFORCED,
ODATE202608145065
23: 37: 3814-Aug-2026JOBZZMPreFlightCheck,
FOLDERZZM_UC_MULTIPATH_CLOUDFORCEDBYUSERemuser5212
23: 37: 3814-Aug-2026SUBMITTEDTOctm-lin-agt.werkstatt.local5105
23: 37: 3914-Aug-2026STARTEDAT20260814233738ONctm-lin-agt.werkstatt.local5101
23: 37: 3914-Aug-2026JOBSTATECHANGEDTOExecuting5120
23: 37: 3914-Aug-2026ENDEDAT20260814233739.OSCOMPSTAT-2.RUNCNT15100
23: 37: 3914-Aug-2026JOBFAILEDTOEXECUTEDUETOUSERENVIRONMENT5112
23: 37: 3914-Aug-2026MessagefromAgent: /opt/ctmag/ctm/sysout/zzm_pre_flight_sh.LOG_0003i7_000015169
23: 37: 3914-Aug-2026ENDEDNOTOK.NUMBEROFFAILURESSETTO15134
23: 37: 3914-Aug-2026JOBSTATECHANGEDTOAnalyzed5120
23: 37: 3914-Aug-2026JobSTATECHANGEDTOPostprocessed5120
23: 55: 1814-Aug-2026RERUNBYUSERemuser5404
23: 55: 1814-Aug-2026SUBMITTEDTOctm-lin-agt.werkstatt.local5105
23: 55: 1814-Aug-2026STARTEDAT20260814235518ONctm-lin-agt.werkstatt.local5101
23: 55: 1814-Aug-2026JOBSTATECHANGEDTOExecuting5120
23: 55: 1914-Aug-2026ENDEDAT20260814235519.OSCOMPSTAT-2.RUNCNT25100
23: 55: 1914-Aug-2026JOBFAILEDTOEXECUTEDUETOUSERENVIRONMENT5112
23: 55: 1914-Aug-2026MessagefromAgent: /opt/ctmag/ctm/sysout/zzm_pre_flight_sh.LOG_0003i7_000025169
23: 55: 1914-Aug-2026ENDEDNOTOK.NUMBEROFFAILURESSETTO25134
23: 55: 1914-Aug-2026JOBSTATECHANGEDTOAnalyzed5120
23: 55: 1914-Aug-2026JobSTATECHANGEDTOPostprocessed5120
23: 58: 5914-Aug-2026RERUNBYUSERemuser5404
23: 58: 5914-Aug-2026SUBMITTEDTOctm-lin-agt.werkstatt.local5105
23: 58: 5914-Aug-2026STARTEDAT20260814235859ONctm-lin-agt.werkstatt.local5101
23: 58: 5914-Aug-2026JOBSTATECHANGEDTOExecuting5120
23: 58: 5914-Aug-2026ENDEDAT20260814235859.OSCOMPSTAT-2.RUNCNT35100
23: 58: 5914-Aug-2026JOBFAILEDTOEXECUTEDUETOUSERENVIRONMENT5112
23: 58: 5914-Aug-2026MessagefromAgent: /opt/ctmag/ctm/sysout/zzm_pre_flight_sh.LOG_0003i7_000035169
23: 58: 5914-Aug-2026ENDEDNOTOK.NUMBEROFFAILURESSETTO35134
23: 58: 5914-Aug-2026JOBSTATECHANGEDTOAnalyzed5120
23: 59: 0014-Aug-2026JobSTATECHANGEDTOPostprocessed5120

```

# Step 4: SNOW Get OAuth Token

# Step 5: SNOW Create Incident

# Step 6: SNOW Add Worklog Entry

# Step 7: SNOW Add Worklog Entry

=== Control-M -> Alerting and Incident Pipeline : DONE ===
