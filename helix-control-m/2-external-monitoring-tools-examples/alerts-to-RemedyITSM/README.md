# Helix Control-M Alerts to Remedy ITSM

## Changes on this version

| Date | Who | What |
| - | - | - |
| 2023-02-09 | Daniel Companeetz | First release |

## Contributions

| Date | Who | What |
| - | - | - |
| 2023-02-09 | Enrique Perez del Razo | Provided knowledge and made ITSM system available for tests |
| 2023-02-09 | Carin Sinclair | Provided knowledge and made ITSM system available for tests |

## Who is using it

| Date | Who | See comments on |
| - | - | - |
|  | |  |

## Short description

Helix Control-M Alerts to Remedy ITSM

## Download

* [Click this to download a zip of the required files](alerts-to-RemedyITSM.zip)  
   Click download and unzip the archive. Then, import the file into the Application Integrator designer.

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
Tested with version BMC Helix ITSM 20.08

## Features

* Authentication: 
  * only Username and password has been developed.
    * The token generated will be expired (logout) at the end of the script.
  * Unaware at this time if there are other methods possible, but reach out if you need other methods (OAuth, etc.)
* Script 
  * will add the log and output to the ticket if configured on the config file (tktvars.json)
  * does not include updates to the ticket.
    * As of the BMC Helix Control-M October 2022 version, there is no API to update tickets
    * When available, special care will be needed for feedback loops as ticket updates will trigger an updated alert to the script.
    will compose a URL for the case to display, if the alert is that of a job.
