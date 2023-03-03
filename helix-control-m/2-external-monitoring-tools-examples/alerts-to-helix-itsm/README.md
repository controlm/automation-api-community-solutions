# Helix Control-M Alerts to Remedy ITSM

## Changes on this version

| Date | Who | What |
| - | - | - |
| 2023-02-09 | Daniel Companeetz | First release |
| 2023-03-03 | Daniel Companeetz | Readme Changes |

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

## Short description

Helix Control-M Alerts to Remedy ITSM

## Pre requisites

### Python packages

1. Remedy_py

Need to install the current fork of the remedy_py package. A pull request is pending for it to be available in PyPI

   ```bash
   pip install git+https://github.com/dcompane/remedy-py
   ```

2. Control-M Python Client

   ```bash
   pip install ctm-python-client
   ```

   Control-M Python Client documentation is available at <https://controlm.github.io/ctm-python-client/>

1. Other packages

   * dotenv

      ```bash
      pip install python-dotenv
      ```

### BMC Helix Control-M

* Helix Control-M
* Automation API CLI

> NOTE: It likely is compatible with Control-M on-premise systems, with the proper fields file (as per the documentation on the [Alerts template reference](https://docs.bmc.com/docs/display/ctmSaaSAPI/Alerts+Template+reference).

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
  * There is a feature for those that want to send an email.
    * If you want to send an email and not the ticket, you will need to comment all lines that send the ticket and ensure variables set at the return are not used in messages later.

## How to use it

### Installation

* Clone this repository

* Install the Automation API CLI in the system you will use to receive the alerts and process them to forward to Helix ITSM.

### Configuration

* Modify your tktvars.json with the appropriate information for your environment
  * You will need credentials and other information from both Helix Control-M and Helix ITSM

* Make your Helix Control-M necessary configurations using the CTM CLI or the scripts in the resources directory

* Test and modify the script as you see necessary. Please remember that this is __*NOT*__ a BMC supported product.
