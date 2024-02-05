## Description

This shell script ([**alerts_to_snmp**](alerts_to_snmp.sh)) sends Helix Control-M alerts data as SNMP traps.

It parses the alert data coming from Helix Control-M (via the External Alerts service) and sends it as a SNMP v1 trap. This can be useful for integration with any application which supports incoming SNMP traps, and especially for customers migrating from Control-M which were using its SNMP notification capabilities.

## Pre-requisites

- Requires the **snmptrap** command line utility, which comes included in the "*net-snmp-utils*" package (see [net-snmp.org](http://www.net-snmp.org/)). As an example, to install it with "yum" package manager (any other required packages are installed too):

    ```
    # yum install net-snmp-utils
    ```

- The provided [**MIB file**](BMC-CONTROLMEM-MIB.txt) (BMC-CONTROLMEM-MIB.txt) must be loaded in the SNMP destination host.

## Instructions

Before using the script, update the following variables:

- **destination** : define the SNMP destination host(s). Use commas ( , ) as delimiter for multiple hosts, and colon ( : ) to use a specific port (default port is 162). Example: ``destination=myhost1,myhost2:2001,192.168.1.37``

- **alert_updates** : select whether you want to send or not updates of existing alerts (which happens when the alert "Status", "Urgency" or "Comment" are updated in Helix Control-M).

## Additional information

- The script uses the default alert field names for Helix Control-M. Therefore, it is NOT required to use a custom template to change the alert fields to their old names in Control-M (as detailed in ["Changing Field Names After Migrating from Onpremises ControlM"](https://documents.bmc.com/supportu/API/Helix/en-US/Documentation/API_Services_RunServices_Alerts_Template_reference.htm#ChangingFieldNamesAfterMigratingfromOnpremisesControlM)). This means that Control-M users migrating to Helix Control-M can use the script without the need to modify the default alerts template.

- The script sends all the alert fields received from Helix Control-M in the SNMP trap, including the "*notes*" field. Refer to the ["Alerts Template reference"](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)) for more details.

- The SNMP v1 trap definition in the "snmptrap" command line contains the `community` ("public"), the destination `host`, the `enterprise-OID` (as defined in the MIB file), the `agent` (IP address of the system generating the trap, empty to use the default value), the `generic-trap` number ("6" for traps defined in a custom MIB file), the `specific-trap` ("10" as defined in the MIB file for the TRAP-TYPE macro) and the `sysUpTime` of the generating application (empty to use the system generated value).

- The "snmptrap" command line is then completed by adding all the alert fields, passed as the payload of the trap. Each of them include the specific `OID`, the `type` ("s" for string) and the `value`.

\
- This is an example of all the data and details from the generated SNMP v1 trap:

    ```
    Message Type: Trap1Message
    Time Received: 04/02/2024 17:52:49
    SNMP Version: One
    Origin Address/Port: 192.168.1.37:50775
    Destination Address/Port: 192.168.1.37:162
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

```
Message Type: Trap1Message
Time Received: 04/02/2024 17:52:49
SNMP Version: One
Origin Address/Port: 192.168.1.37:50775
Destination Address/Port: 192.168.1.37:162
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

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2024-02-04 | David Fernández | First release |
