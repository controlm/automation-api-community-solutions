## Description

Send BMC Helix Control-M alerts to BMC Remedy ITSM

## Pre-requisites

### Python packages

1. Remedy_py

   The current fork of the *remedy_py* package needs to be installed. A pull request is pending for it to be available in PyPI.

   ```bash
   pip install git+https://github.com/dcompane/remedy-py
   ```

2. Control-M Python Client

   ```bash
   pip install ctm-python-client
   ```
   You can find more information in the [Control-M Python Client documentation](https://controlm.github.io/ctm-python-client/).
     
3. Dotenv
   
      ```bash
      pip install python-dotenv
      ```

### BMC Helix Control-M

- Helix Control-M
- Automation API CLI

``NOTE: It is likely compatible with Control-M on-premise systems, with the proper fields file (as per the documentation on the [Alerts template reference](https://docs.bmc.com/docs/display/ctmSaaSAPI/Alerts+Template+reference)).``

### BMC Helix ITSM

- BMC Helix ITSM or BMC Remedy on-prem with REST APIs enabled.
- Tested with BMC Helix ITSM version 20.08.

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

## Versions

| Date | Who | What |
| - | - | - |
| 2023-02-09 | Daniel Companeetz | First release |



## Instructions

BLABLABLA


## Additional information

BLABLABLA