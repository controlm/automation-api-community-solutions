## Description

This Linux (bash) script sends BMC Helix Control-M alerts to BMC Helix Operations Management.

It parses the alert data coming from BMC Helix Control-M (HCTM) into JSON format, and then sends it to BMC Helix Operations Management (BHOM) using its event ingestion API. The JSON data is structured according to a provided event class which has to be previously created in BHOM.



## Pre-requisites

- Create the event class in BHOM using the [bhom_ControlMEvent_class.json](bhom_ControlMEvent_class.json) file.


  "parentClassName": "MonitorEvent"

1. Remedy_py

   The current fork of the *remedy_py* package needs to be installed. A pull request is pending for it to be available in PyPI.

   ```bash
   pip install git+https://github.com/dcompane/remedy-py
   ```

2. Control-M Python Client

   ```bash
   pip install ctm-python-client
   ```
   You can find related information in the [Control-M Python Client documentation](https://controlm.github.io/ctm-python-client/).
     
3. Dotenv
   
      ```bash
      pip install python-dotenv
      ```

## Instructions

*MISSING*

## Additional information

- Only username and password authentication has been developed.
- The token generated will expire (logout) at the end of the script.
- The script will add the job log and output to the ticket if configured on the config file (*tktvars.json*).
- The script does not include updates to the ticket (as it it not supported yet in BMC Helix Control-M).
- If the alert is related to a job, a URL is created for access to the Helix Control-M web interface - directly to a monitoring viewpoint showing the problematic job and its neighborhood.

## Recognition

Special thanks to (in no particular order!):

- Carin Sinclair : Provided knowledge and made ITSM system available for tests.
- Cecilia Lasecki : Helped with setting up BMC Demo Cloud instances.
- Enrique Perez del Razo : Provided knowledge and made ITSM system available for tests.
- Marta Zamorano Justel : Helped with setting up BMC Demo Cloud instances.
- Wendel Bordelon : Sanity check (hard work!) and suggestions for improving the ticket content.

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2023-02-09 | Daniel Companeetz | First release |
