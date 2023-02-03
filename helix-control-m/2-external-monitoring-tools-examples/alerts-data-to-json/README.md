## Description

This Linux (bash) script converts the received alert data to JSON, which can be useful when an external tool is expecting the input data in such format.

As an example, the alert data is saved into a file, but this could be replaced by any other action (e.g. sending the alert data in JSON via a webhook).

## Usage

- If you use the script as it is (saving the JSON data into a file), update the **alerts_dir** and **alerts_file** variables with your custom file location.

- If you have modified the default JSON template for alerts (which determines the information to provide: alert fields, names and order of appearance - as documented in the [**Alerts Template reference**](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)), remember to update the **field_names** variable in the script with the corresponding field names and their order.

## Additional information

The alert data is passed as parameters to the script with the format `<field1>: <value1> <field2>: <value2> [...]`, as in the following example:

    eventType: I id: 2193 server: IN01 fileName: runId: 00q2e severity: V status: 0 time: 20221126150057 user: updateTime: message: Ended not OK runAs: ctmagent subApplication: application: my-demos jobName: my-sample-job host: zzz-linux-agent-1 type: R closedByControlM: ticketNumber: runNo: 00001 notes:

The script parses the input data and converts it to JSON format, starting with the "*alertFields*" key and followed by an array containing all the alert fields and their corresponding values. This is the same JSON structure as the one received when connecting to the External Alerts service via a WebSocket client, as in the following example:

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