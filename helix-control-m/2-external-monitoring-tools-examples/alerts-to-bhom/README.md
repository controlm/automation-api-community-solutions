## Description

This Linux (bash) script sends BMC Helix Control-M alerts as events to BMC Helix Operations Management.

It parses the alert data coming from Helix Control-M (**HCTM**) into JSON format, and then sends it to Helix Operations Management (**BHOM**) using its event ingestion API. The JSON data is mapped according to an event class which has to be previously created in BHOM.

## Pre-requisites

- **Create a new Event Class** in BHOM, using the definition from the [**bhom_ctm_event_class.json**](bhom_ctm_event_class.json) file.

   This event class called "ControlMEvent" includes all the fields from the HCTM alert data, plus one additional field to include a link to the job that generated the alert (when applicable).
   
   *Some HCTM alert fields are not included in this class, as they already exist in its parent class "MonitorEvent" or in the base class "Event".*
   
   To create the event class, follow the BHOM documentation for [Event management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-management-endpoints-in-the-rest-api-1160751462.html) (*remember to select your product version*), and use the "POST /events/classes" endpoint.
   
-  **Import an Event Policy** in BHOM, using the [**bhom_ctm_event_policy.json**](bhom_ctm_event_policy.json) file.  **[OPTIONAL]**

   This policy has been created to automatically:
      - update existing events coming from HCTM if they already exist in BHOM (which happens when the alert "Status", "Urgency" or "Comment" fields are updated in HCTM), and
      - map the HCTM alert status to the BHOM event (e.g. close the event in BHOM if the alert is closed in HCTM).

   To import the event policy from the BHOM console, go to the "Configuration" menu and select "Event Policies", click on the import button (on the top right corner of the screen, right to the "Create" button) and attach the json file. Once imported, remember to select the policy name and click on the "Enable" button.

   To import the event policy using the API, follow the BHOM documentation for [Event policy management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-policy-management-endpoints-in-the-rest-api-1160751484.html), and use the "POST /event_policies" endpoint.

   If you decide to use this event policy, remember to set the "alert_updates" variable in the script as "Y" (*if not, alert updates are not sent to BHOM and the policy will never apply*).

## Instructions

The [**alerts_bhom.sh**](alerts_bhom.sh) script is intended to be used with the **External Alert Management** service from the Automation API, which allows to define a script to trigger each time an alert is received (for more information, see the HCTM documentation for [Setting Up External Alerts](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/Alerts.htm#SettingUpExternalAlerts) and [External Alert Management](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alert_managementExternalAlertManagement)).

Before using the script, please update the following parameters:

- **hctm_url** : enter the URL for the HCTM tenant (e.g. "*https://\<tenant name\>.us1.controlm.com*").
- **bhom_url** : enter the URL for the BHOM event data endpoint (e.g. "*https://\<BMC Helix Portal URL\>/events-service/api/v1.0/events*"), as described in the BHOM documentation for [Policy, event data, and metric data management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/policy-event-data-and-metric-data-management-endpoints-in-the-rest-api-1160751457.html).
- **bhom_api_key** : enter a valid BHOM API key, which you can obtain from the BHOM console in the "Administration" menu, selecting "Repository" and clicking on "Copy API Key".
- **sev_V/U/R** : update the three parameters to set the HCTM to BHOM correspondence for the "severity" field according to your preferences (alerts coming from HCTM can be Very urgent, Urgent or Regular, while BHOM event severity can be CRITICAL, MAJOR, MINOR, WARNING, INFO, OK or UNKNOWN).
- **alert_updates** : select whether you want to send or not updates of existing HCTM alerts to BHOM (which happens when the alert "Status", "Urgency" or "Comment" fields are updated in HCTM).

Do NOT modify the following parameters:

- **bhom_class** : leave as is to use the previously imported "ControlMEvent" event class.
- **alert_updates** : leave as is to use the default field names for HCTM alerts. If you have previously modified the JSON template for alerts in HCTM, restore the default alert fields (as documented in the [Alerts Template reference](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)).

## Additional information

- You can create an **Event Group** in BHOM for HCTM alerts:

   - In the BHOM console, go to the "Configuration" menu and select "Groups".
   - In the "Group Information" section, enter the group name (e.g. "Helix Control-M") and a description.
   - In the "Selection Query" section, go to "Event Selection Criteria" and add "Class Equals ControlMEvent".
   - Save the Group. Now you can go to the "Monitoring" menu, select "Groups" and click the one you just created to view only events related to HCTM.

- You can create a custom **Table View** in BHOM to show any HCTM alert fields of your choice in the main "Events" or "Groups" dashboards.

   - Follow the steps in the BHOM documentation for [Creating table views](https://docs.bmc.com/docs/helixoperationsmanagement/231/creating-table-views-1160750840.html).
   - For example, a custom table view can be used to show the "jobLink" field in the main event dashboard, which when clicked will open the HCTM web interface with a monitoring viewpoint showing the problematic job and its neighborhood (when the alert is related to a job, and as long as the user is already logged in the HCTM web interface).

- If you get the error "*curl: (48) An unknown option was passed in to libcurl*" when testing the script, uncomment the following line: 

    ``export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"``

- Misc information about the script:

   - Some HCTM alert field names are changed to avoid conflicts with BHOM fields inherited from the event parent classes (such as "status" > "alertStatus" and "time" > "alertTime").
   - Some HCTM alert field names are changed to map them to BHOM event fields (such as "message" > "msg" and "host" > "source_hostname").
   - Add link to job (only if "host" was not empty, meaning it is an alert related to a job), job link is created with the "runId", "server", "jobName"

- The following table shows the correspondence between the HCTM and BHOM field names, and any additional field modifications done in the script.

- Versions information?

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2023-02-09 | David Fernández | First release |


| HCTM field name | BHOM field name | Comments |
| - | - | - |
| eventType | eventType | Not modified. |


eventType			eventType					
id				alertId			Y		
server			ctmServer			Y		
fileName			fileName					
runId				runId						
severity			severity							N
status			alertStatus		Y
time				alertTime			Y
user				ctmUser			Y
updateTime			updateTime			
message			msg				Y				N
runAs				runAs				
subApplication		subApplication		
application		application		
jobName			jobName			
host				source_hostname		Y				N
type				alertType			Y
closedByControlM	closedByControlM	
ticketNumber		ticketNumber		
runNo				runNo				
notes				alertNotes			Y
				jobLink			Y