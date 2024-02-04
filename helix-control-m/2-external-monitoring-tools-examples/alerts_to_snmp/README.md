## Description

This shell script ([**alerts_to_snmp**](alerts_to_snmp.sh)) sends Helix Control-M alerts data as SNMP (v1) traps.

As an example, the alert data is saved into a file, but this could be replaced by any other action (e.g. sending the alert data as a JSON payload via a webhook).

## Pre-requisites

- Requires the **snmptrap** command line utility, which comes included in the "net-snmp-utils" package (see [net-snmp.org](http://www.net-snmp.org/)).

- The provided MIB file ([**BMC-CONTROLMEM-MIB**](BMC-CONTROLMEM-MIB.txt)) must be loaded in the SNMP destination host.

## Instructions

Before using the script, update the following variables:

- **destination** : define the SNMP destination host(s). Use commas ( , ) as delimiter for multiple hosts, and colon ( : ) to use a specific port (default port is 162). Example:

  ``destination=myhost1,myhost2:2001,192.168.1.37``

- **alert_updates** : select whether you want to send or not updates of existing alerts (which happens when the alert "Status", "Urgency" or "Comment" are updated in Helix Control-M).

## Additional information

- The SNMP v1 trap definition in the "snmptrap" command line contains the `community` (*public*), the destination `host`, the `enterprise-OID` (as defined in the MIB file), the `agent` (IP address of the system generating the trap, empty to use the default value), the `generic-trap` number ("6" for traps defined in a custom MIB file), the `specific-trap` ("10" as defined in the MIB file for the TRAP-TYPE macro) and the `sysUpTime` of the generating application (empty to use the system generated value).

- The "snmptrap" command line is then completed by adding all the alert fields, passed as the payload of the trap. Each of them include the specific `OID`, the `type` ("s" for string) and the `value`.

- The script sends all the alert fields received from Helix Control-M in the SNMP trap, including the "*notes*" field. Refer to the ["Alerts Template reference"](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)) for more details.

- The script uses the default alert field names for Helix Control-M. Therefore, it is NOT required to use a custom template to change the alert fields to their old names in Control-M (as detailed in ["Changing Field Names After Migrating from Onpremises ControlM"](https://documents.bmc.com/supportu/API/Helix/en-US/Documentation/API_Services_RunServices_Alerts_Template_reference.htm#ChangingFieldNamesAfterMigratingfromOnpremisesControlM)). This means that Control-M users migrating to Helix Control-M can use the script without the need to modify the default alerts template.

- This is an example of all the data generated in the SNMP v1 trap:

```
Message Type: Trap1Message
Time Received: 04/02/2024 17:52:49
SNMP Version: One
Origin Address/Port: 192.168.1.37:50775
Destination Address/Port: 192.168.1.37:161
Community: public
Variable IIDs and Values:
    1.3.6.1.4.1.1031.9.1.1 (alertTrapUpdateType): I
    1.3.6.1.4.1.1031.9.1.2 (alertTrapAlertId): 25101
    1.3.6.1.4.1.1031.9.1.3 (alertTrapControlM): IN01
    1.3.6.1.4.1.1031.9.1.4 (alertTrapMemName): 
    1.3.6.1.4.1.1031.9.1.5 (alertTrapOrderId): 0e4oe
    1.3.6.1.4.1.1031.9.1.6 (alertTrapSeverity): V
    1.3.6.1.4.1.1031.9.1.7 (alertTrapStatus): Not_Noticed
    1.3.6.1.4.1.1031.9.1.8 (alertTrapTime): 20240204165241
    1.3.6.1.4.1.1031.9.1.9 (alertTrapUser): 
    1.3.6.1.4.1.1031.9.1.10 (alertTrapUpdateTime): 
    1.3.6.1.4.1.1031.9.1.11 (alertTrapMessage): Ended not OK
    1.3.6.1.4.1.1031.9.1.12 (alertTrapOwner): ctmagent
    1.3.6.1.4.1.1031.9.1.13 (alertTrapGroup): 
    1.3.6.1.4.1.1031.9.1.14 (alertTrapApplication): dfe-demos
    1.3.6.1.4.1.1031.9.1.15 (alertTrapJobName): dfe-job-01
    1.3.6.1.4.1.1031.9.1.16 (alertTrapNodeId): zzz-linux-agent-0
    1.3.6.1.4.1.1031.9.1.17 (alertTrapType): R
    1.3.6.1.4.1.1031.9.1.18 (alertTrapClosedFromEM): 
    1.3.6.1.4.1.1031.9.1.19 (alertTrapTicketNumber): 
    1.3.6.1.4.1.1031.9.1.20 (alertTrapRunCounter): 00001
    1.3.6.1.4.1.1031.9.1.21 (alertTrapNotes):
Agent IP:192.168.182.60
Enterprise: 1.3.6.1.4.1.1031.9.1
Generic Trap: 6
Specific Trap: 10
```

XXX format `<field1>: <value1> <field2>: <value2> [...]`, as in the following example:


The script parses the input data and converts it to JSON format, starting with the "*alertFields*" key and followed by an array containing all the alert fields and their corresponding values - as in the example below. This is the same JSON structure as the one received when connecting to the External Alerts service via a WebSocket client.

    {
       "alertFields" : [
          {"eventType" : "I"},
          {"id" : "2193"},
          {"server" : "IN01"},
          {"fileName" : ""},
          {"runId" : "00q2e"},
          {"severity" : "V"},
          {"status" : "0"},
          {"time" : "20221126150057"},
          {"user" : ""},
          {"updateTime" : ""},
          {"message" : "Ended not OK"},
          {"runAs" : "ctmagent"},
          {"subApplication" : ""},
          {"application" : "my-demos"},
          {"jobName" : "my-sample-job"},
          {"host" : "zzz-linux-agent-1"},
          {"type" : "R"},
          {"closedByControlM" : ""},
          {"ticketNumber" : ""},
          {"runNo" : "00001"},
          {"notes" : ""}
        ]
    }

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2024-02-04 | David Fernández | First release |
