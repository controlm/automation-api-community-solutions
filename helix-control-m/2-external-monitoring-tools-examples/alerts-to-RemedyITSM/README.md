## Description

Send BMC Helix Control-M alerts to BMC Remedy ITSM

## Versions

- 2023-02-09 : Daniel Companeetz : First release

## Pre-requisites

### Python packages

1. Remedy_py : Need to install the current fork of the *remedy_py* package. A pull request is pending for it to be available in PyPI.

   ``bash
   pip install git+https://github.com/dcompane/remedy-py
   ``

2. Control-M Python Client

   ```bash
   pip install ctm-python-client
   ```

   Control-M Python Client documentation is available at <https://controlm.github.io/ctm-python-client/>

3. Other packages

   * dotenv

      ```bash
      pip install python-dotenv
      ```

### BMC Helix Control-M

* Helix Control-M
* Automation API CLI

> NOTE: It is likely compatible with Control-M on-premise systems, with the proper fields file (as per the documentation on the [Alerts template reference](https://docs.bmc.com/docs/display/ctmSaaSAPI/Alerts+Template+reference).

### BMC Helix ITSM

BMC Helix Remedy ITSM or on-prem with REST APIs enabled.
* Tested with version BMC Helix ITSM 20.08

## Features

* Authentication
  * only Username and password has been developed.
    * The token generated will be expired (logout) at the end of the script.
  * Unaware at this time if there are other methods possible, but reach out if you need other methods (OAuth, etc.)
* The script
  * will add the log and output to the ticket if configured on the config file (tktvars.json)
  * does not include updates to the ticket.
    * As of the BMC Helix Control-M October 2022 version, there is no API to update tickets (estimated for June 2023)
    * When available, special care will be needed for feedback loops as ticket updates will trigger an updated alert to the script.
  * will compose a URL for the case to display, if the alert is that of a job.


## Recognition

* The ones below help on the good outcomes.(no particular order!)
* The bad ones are me to blame for!

| Date | Who | What |
| - | - | - |
| 2023-02-09 | Carin Sinclair | Provided knowledge and made ITSM system available for tests |
| 2023-02-09 | Cecilia Lasecki | Helped with setting up BMC Demo Cloud instances |
| 2023-02-09 | Enrique Perez del Razo | Provided knowledge and made ITSM system available for tests |
| 2023-02-09 | Marta Zamorano Justel | Helped with setting up BMC Demo Cloud instances |
| 2023-02-09 | Wendel Bordelon | Sanity Check (hard work!) and suggestions for improving the ticket content |

## Contributions
| Date | Who | What |
| - | - | - |
|  |  |  |
## Who is using it

| Date | Who | Notes |
| - | - | - |
|  | |  |


## Instructions

- If you use the script as it is (saving the alert data into a file), update the **alerts_dir** and **alerts_file** variables with your custom file location.

- If you have modified the default JSON template for alerts (which determines the information to provide: alert fields, names and order of appearance - as documented in the [**Alerts Template reference**](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)), remember to update the **field_names** variable in the script with the corresponding field names and their order.

## Additional information

The alert data is passed as parameters to the script with the format `<field1>: <value1> <field2>: <value2> [...]`, as in the following example:

    eventType: I id: 2193 server: IN01 fileName: runId: 00q2e severity: V status: 0 time: 20221126150057 user: updateTime: message: Ended not OK runAs: ctmagent subApplication: application: my-demos jobName: my-sample-job host: zzz-linux-agent-1 type: R closedByControlM: ticketNumber: runNo: 00001 notes:

As some fields can have an empty value, it is not possible to simply reference the input parameters as $1, $2, $3, etc - as the order may change. This scripts simplifies using each field value in the script, which can be referenced simply as variables with the same field name, as in the the following example:

    echo "$time | $id | $severity | $runId | $application | $jobName | $host | $message" >> myfile.txt