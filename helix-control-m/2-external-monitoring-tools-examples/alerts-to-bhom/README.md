## Description

This Linux (bash) script sends BMC Helix Control-M alerts to BMC Helix Operations Management.

It parses the alert data coming from BMC Helix Control-M (HCTM) into JSON format, and then sends it to BMC Helix Operations Management (BHOM) using its event ingestion API. The JSON data is structured according to a provided event class which has to be previously created in BHOM.



## Pre-requisites

- **Create a new Event Class in BHOM**, as defined in the [bhom_ControlMEvent_class.json](bhom_ControlMEvent_class.json) file.

   This event class called "ControlMEvent" includes all the fields from the HCTM alert data, plus one additional field to include a link to the job that generated the alert (when applicable). Some HCTM alert fields are not included in this class, as they are existing BHOM event fields inherited from the parent class "MonitorEvent".

   To create the event class, follow the BHOM documentation for [Event management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-management-endpoints-in-the-rest-api-1160751462.html) (*remember to select your product version*), and use the "/events/classes" endpoint from the REST API.
   
-  **Import the Event Policy** provided in the [bhom_update_ctm_events_policy.json](bhom_update_ctm_events_policy.json) file. **[OPTIONAL]**

   This policy has been created to automatically 1) update existing events coming from HCTM if they already exist in BHOM (which happens when the alert "Status", "Urgency" or "Comment" fields are updated in HCTM), and 2) close the event in BHOM if the alert is marked as "Closed" in HCTM.

   To import the event policy from the BHOM web interface, go to the "Configuration" menu and select "Event Policies", click on the import button (on the top right corner of the screen, right to the "Create" button) and attach the json file. Once imported, remember to select the policy name and click on the "Enable" button.

   If you want to import it using the API, follow the BHOM documentation for [Event policy management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-policy-management-endpoints-in-the-rest-api-1160751484.html), and use the */event_policies* endpoint.

   If you use this event policy, remember to define the "alert_updates" variable in the script with the "Y" value (if not, alert updates are not sent to BHOM and the policy does not make sense).

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
