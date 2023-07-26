#!/bin/bash
#
# Sends BMC Helix Control-M (HCTM) alerts as events to BMC Helix Operations Management (BHOM)
#
# Notes : - The alert data is sent in JSON format to BHOM using its event ingestion API
#         - The "ControlMAlert" event class must be previously imported in BHOM
#         - Update variables below according to your environment and preferences
#

# Set HCTM parameters
hctm_url=https://<your_HCTM_URL>
hctm_name="Helix Control-M"

# Set BHOM parameters
bhom_url=https://<your_BHOM_URL>/events-service/api/v1.0/events
bhom_api_key=<your_BHOM_API_Key>
bhom_class="ControlMAlert"

# Set HCTM to BHOM correspondence for the "severity" field
# HCTM : V (Very urgent), U (Urgent), R (Regular) | BHOM : CRITICAL, MAJOR, MINOR, WARNING, INFO, OK, UNKNOWN
sev_V="CRITICAL"
sev_U="MAJOR"
sev_R="MINOR"

# Send updates of existing alerts? (Y/N)
alert_updates="Y"

# Declare arrays with the HCTM alert fields and BHOM slot names - DO NOT MODIFY
alert_fields=("eventType" "id" "server" "fileName" "runId" "severity" "status" "time" "user" "updateTime" "message" "runAs" "subApplication" "application" "jobName" "host" "type" "closedByControlM" "ticketNumber" "runNo" "notes")
bhom_slots=("eventType" "alertId" "ctmServer" "fileName" "runId" "severity" "alertStatus" "creation_time" "ctmUser" "updateTime" "msg" "runAs" "subApplication" "application" "jobName" "source_hostname" "alertType" "closedByControlM" "ticketNumber" "runNo" "alertNotes")

# If alert updates are not needed, exit if "call_type" = "U"
if [ $alert_updates == "N" ] ; then
   if [ $2 == "U" ] ; then exit 0 ; fi
fi

# Start JSON and add first BHOM slots
hctm_tenant=`echo $hctm_url | cut -c 9-`
json_data="[ { \"class\" : \"$bhom_class\", \"location\" : \"$hctm_name\", \"source_identifier\" : \"$hctm_tenant\""

# Start creating url for the job link
job_link=$hctm_url"/ControlM/Monitoring/Neighborhood/?"

# START PROCESSING ALERT DATA
num_fields=${#alert_fields[@]}
for (( i=0; i<=$((num_fields-1)); i++ )) ; do
   field=${alert_fields[$i]}
   next_field=${alert_fields[$i+1]}
   if [ $i != $((num_fields-1)) ] ; then
      value=`echo $* | grep -oP "(?<=\b${field}\b: ).*?(?= \b${next_field}\b:)"`   
      
      # Update some fields for BHOM compatibility
      case $field in
         server)
            # Save "server" value in a variable (for the job link)
            ctm_server=$value
         ;;
         runId)
            # Add "runId" and "server" to the job link
            job_link=$job_link"orderId="$value"&ctm="$ctm_server
         ;;
         severity)
            # Convert "severity" format from HCTM to BHOM
            bhom_severity="sev_${value}"
            value=${!bhom_severity}
         ;;
         time | updateTime)
            # Convert to Epoch time, in milisecs
            D="$value"
            value=`date -d "${D:0:8} ${D:8:2}:${D:10:2}:${D:12:2} +0000" "+%s%3N"`
         ;;
         jobName)
            # Add "jobName" to the final job link
            job_name="${value// /%20}"  # Replace spaces by "%20"
            job_link=$job_link"&name="$job_name"&odate=%20&direction=1&radius=3"  # Direction and radius can be customized
         ;;
         host)
            # Save "host" value in a variable (used to determine whether to include the job link)
            saved_host=$value
         ;;
      esac

   else
      # If last field, capture until EOL
      value=`echo $* | grep -oP "(?<=\b${field}\b: ).*"`
   fi
   slot_name=${bhom_slots[$i]}
   text=", \"$slot_name\" : \"$value\""
   json_data=$json_data$text
done

# Add link to the problematic job (only if "host" was not empty, meaning it is an alert related to a job)
if [ ! -z "$saved_host" ] ; then
   json_data=$json_data", \"jobLink\" : \"$job_link\""
fi      

# Close JSON
json_data=$json_data" } ]"

# Set library path to solve curl error when Helix Control-M Agent is installed
# USE ONLY if you get the error: "curl: (48) An unknown option was passed in to libcurl"
# See https://bmcsites.force.com/casemgmt/sc_KnowledgeArticle?sfdcid=kA33n000000YHinCAG&type=Solution
# export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"

# Send HCTM alert data to BHOM
curl -X POST $bhom_url -H "Authorization: apiKey $bhom_api_key" -H 'Content-Type: application/json' -d "$json_data"

exit 0
