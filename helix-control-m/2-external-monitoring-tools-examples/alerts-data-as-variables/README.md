## Description

This Linux (bash) script parses the alert data into individual variables.

This simplifies using any alert fields in the script, which then can be used as `$<field>` (e.g. $runId, $message, $jobName, etc) when calling the command used to send the alerts to an external tool.

As an example, the alert data is saved into a file, but this could be replaced by any other action.

## Instructions

- If you use the script as it is (saving the alert data into a file), update the **alerts_dir** and **alerts_file** variables with your custom file location.

- If you have modified the default JSON template for alerts (which determines the information to provide: alert fields, names and order of appearance - as documented in the [**Alerts Template reference**](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)), remember to update the **field_names** variable in the script with the corresponding field names and their order.

## Additional information

The alert data is passed as parameters to the script with the format `<field1>: <value1> <field2>: <value2> [...]`, as in the following example:

    eventType: I id: 2193 server: IN01 fileName: runId: 00q2e severity: V status: 0 time: 20221126150057 user: updateTime: message: Ended not OK runAs: ctmagent subApplication: application: my-demos jobName: my-sample-job host: zzz-linux-agent-1 type: R closedByControlM: ticketNumber: runNo: 00001 notes:

As some fields can have an empty value, it is not possible to simply reference the input parameters as $1, $2, $3, etc - as the order may change. This scripts simplifies using each field value in the script, which can be referenced simply as variables with the same field name, as in the the following example:

    echo "$time | $id | $severity | $runId | $application | $jobName | $host | $message" >> myfile.txt

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2023-02-03 | David Fernández | First release |