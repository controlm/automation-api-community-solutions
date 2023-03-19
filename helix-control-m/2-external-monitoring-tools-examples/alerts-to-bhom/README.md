## Description

This shell script ([**alerts_to_bhom.sh**](alerts_to_bhom.sh)) sends BMC Helix Control-M alerts as events to BMC Helix Operations Management.

It parses the alert data coming from Helix Control-M (**HCTM**) into JSON format, and then sends it to Helix Operations Management (**BHOM**) using its event ingestion API. The JSON data is structured according to an event class which has to be previously created in BHOM.

## Pre-requisites

- **Configure the HCTM "External Alert Management" service** from the Automation API to execute the script every time an alert is raised.
 
  - For more information, check the HCTM documentation for [Setting Up External Alerts](https://documents.bmc.com/supportu/controlm-saas/en-US/Documentation/Alerts.htm#SettingUpExternalAlerts) and the HCTM Automation API documentation for [External Alert Management](https://docs.bmc.com/docs/saas-api/run-service-941879047.html#Runservice-alert_managementExternalAlertManagement).

  - As explained in the documentation, you need to use "run alerts:listener:script::set" to define the path to the script - and then open the alerts stream and start the alerts listener process.

- **Create a new Event Class in BHOM**, using the definition from the [**bhom_ctm_event_class.json**](bhom_ctm_event_class.json) file.

  This event class called "**ControlMAlert**" includes all the required fields from the HCTM alert data, plus one additional field to include a link to the job that generated the alert (when applicable). It also inherits all fields from its parent classes "IIMonitorEvent", "MonitorEvent" and the "Event" base class (check the BHOM documentation on [Event classification and formatting](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-classification-and-formatting-1160751038.html) for more details).

  - To create the event class, contact your BHOM administrator or follow the documentation for [Event management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-management-endpoints-in-the-rest-api-1160751462.html) (*remember to select your product version*), and use the "POST /events/classes" endpoint.

  - If the "IIMonitorEvent" event class is not available in your BHOM environment, you can update the json file to use the "MonitorEvent" class instead.
   
- **Import an Event Policy in BHOM**, using the [**bhom_ctm_event_policy.json**](bhom_ctm_event_policy.json) file.  **[OPTIONAL]**

  This event policy can be useful when alerts are also managed from HCTM (e.g. when an operator uses the HCTM web interface to close an alert, modify the urgency or add a comment), and we want to automatically reflect those changes in BHOM. If the HCTM alerts are only going to be managed from BHOM, there is no need to import this event policy.

  Depending on the case, remember to set the "**alert_updates**" variable in the script accordingly (Y/N). If set to "N", alert updates are not sent to BHOM (and the policy will never apply, even if imported). If set to "Y", it is recommended to use the policy to avoid creating duplicate events in BHOM every time the alert details are updated from HCTM.

  The event policy will automatically 1) update existing events coming from HCTM if they already exist in BHOM (which happens when the alert "Status", "Urgency" or "Comment" are updated in HCTM), 2) map the status from the HCTM alert to the BHOM event (e.g. close the event in BHOM if the alert is closed in HCTM), and 3) record the last alert comment into the BHOM notes history. Be aware that, if the event is closed in BHOM and the associated alert is updated from HCTM, a new event (with the same "alertId") will be created.

  - To import the event policy from the BHOM console, go to the "Configuration" menu and select "Event Policies", click on the import button (located on the top right corner, right to the "Create" button) and attach the json file. Once imported, remember to select the policy name and click on the "Enable" button.

  - To import the event policy using the API, follow the BHOM documentation for [Event policy management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/event-policy-management-endpoints-in-the-rest-api-1160751484.html), and use the "POST /event_policies" endpoint.

## Instructions

Before using the script, update the following variables:

- **hctm_url** : enter the URL for the HCTM tenant (e.g. "*https://\<tenant name\>.us1.controlm.com*").
- **hctm_name** : the default is "Helix Control-M", but can be updated to e.g. use different names for multiple HCTM environments (the value is assigned to the BHOM "location" field).
- **bhom_url** : enter the URL for the BHOM event data endpoint (e.g. "*https://\<BMC Helix Portal URL\>/events-service/api/v1.0/events*"), as described in the BHOM documentation for [Policy, event data, and metric data management endpoints in the REST API](https://docs.bmc.com/docs/helixoperationsmanagement/231/policy-event-data-and-metric-data-management-endpoints-in-the-rest-api-1160751457.html).
- **bhom_api_key** : enter a valid BHOM API key, which you can obtain from the BHOM console in the "Administration" menu, selecting "Repository" and clicking on "Copy API Key".
- **sev_V/U/R** : update the three variables to set the HCTM to BHOM correspondence for the "severity" field according to your preferences (alerts coming from HCTM can be Very urgent, Urgent or Regular; while BHOM event severity can be CRITICAL, MAJOR, MINOR, WARNING, INFO, OK or UNKNOWN).
- **alert_updates** : select whether you want to send or not updates of existing HCTM alerts to BHOM (which happens when the alert "Status", "Urgency" or "Comment" are updated in HCTM).

Do NOT modify the following variables:

- **bhom_class** : leave as is to use the previously imported "ControlMAlert" event class.
- **alert_fields** : leave as is to use the default field names for HCTM alerts. If you have previously modified the JSON template for alerts in HCTM, restore the default alert fields (as documented in the [Alerts Template reference](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html)).
- **bhom_slots** : leave as is to use the default event slots defined in the "ControlMAlert" class.

## Additional information

- The integration has been tested with:

   - BMC Helix Control-M 9.0.21.080
   - BMC Helix Operations Management 23.1

- You can create an **Event Group** in BHOM to show HCTM alerts only:

   - In the BHOM console, go to the "Configuration" menu, select "Groups" and click on "Create".
   - In the "Group Information" section, enter the group name (e.g. "Helix Control-M") and a description.
   - In the "Selection Query" section, go to "Event Selection Criteria" and add "Class Equals ControlMAlert".
   - Save the Group. Now you can go to the "Monitoring" menu, select "Groups" and click on the one you just created to view only events related to HCTM.

- You can create a custom **Table View** in BHOM to show any HCTM alert fields of your choice in the "Events" or "Groups" dashboards.

   - Follow the steps in the BHOM documentation for [Creating table views](https://docs.bmc.com/docs/helixoperationsmanagement/231/creating-table-views-1160750840.html).
   - For example, a custom table view can be used to show the "jobLink" field in the main event dashboard, which when clicked will open the HCTM web interface with a monitoring viewpoint showing the problematic job and its neighborhood (when the alert is related to a job, and as long as the user is already logged in the HCTM web interface).

- If you get the error "*curl: (48) An unknown option was passed in to libcurl*" when testing the script, uncomment the following line: 

  ``export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"``

- The following table shows the correspondence between the HCTM alert fields and the BHOM event slots (defined in the "ControlMAlert" class or inherited from its parent classes), plus additional information for fields which are modified in the script.

  For more information on the HCTM alert fields, check the [Alerts Template reference](https://docs.bmc.com/docs/saas-api/alerts-template-reference-1144242602.html) documentation.

  | HCTM alert field | BHOM event slot | Comments |
  | - | - | - |
  | ``eventType`` | ``eventType`` | |
  | ``id`` | ``alertId`` | |
  | ``server`` | ``ctmServer`` | |
  | ``fileName`` | ``fileName`` | |
  | ``runId`` | ``runId`` | |
  | ``severity`` | ``severity`` | The value is updated to map the HCTM to BHOM correspondence. Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``status`` | ``alertStatus`` | |
  | ``time`` | ``creation_time`` | The value is converted to the format expected by BHOM (Epoch time, in milliseconds). Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``user`` | ``ctmUser`` | |
  | ``updateTime`` | ``updateTime`` | The value is converted to the format expected by BHOM (Epoch time, in milliseconds). |
  | ``message`` | ``msg`` | Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``runAs`` | ``runAs`` | |
  | ``subApplication`` | ``subApplication`` | |
  | ``application`` | ``application`` | |
  | ``jobName`` | ``jobName`` | |
  | ``host`` | ``source_hostname`` | When the alert "host" value is empty, it defaults to the "source_identifier" event slot. Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |
  | ``type`` | ``alertType`` | |
  | ``closedByControlM`` | ``closedByControlM`` | |
  | ``ticketNumber`` | ``ticketNumber`` | |
  | ``runNo`` | ``runNo`` | |
  | ``notes`` | ``alertNotes`` | |
  | | ``jobLink`` | Additional slot included in the "ControlMAlert" class, which value is defined in the script using the HCTM tenant URL, runId, ctmServer and jobName.  |
  | | ``location`` | The value is defined in the script using the "hctm_name" variable. Not included in the "ControlMAlert" class, as it is inherited from the base class "Event".  |
  | | ``source_identifier`` | The value is defined in the script using the HCTM tenant URL (removing the "https://"). Not included in the "ControlMAlert" class, as it is inherited from the base class "Event". |

  *The script could be modified to also pass the ``external_id`` slot from the "IIMonitorEvent" class, in order to associate the event with a CI (configuration item).*

## Versions

| Date | Updated by | Changes |
| - | - | - |
| 2023-03-18 | David Fernández | First release |
