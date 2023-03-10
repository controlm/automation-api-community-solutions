#!/bin/bash
#
# Sends BMC Helix Control-M (HCTM) alerts as events to BMC Helix Operations Management (BHOM)
#
# Notes : - The alert data is sent in JSON format to BHOM using its event ingestion API
#         - The "ControlMAlert" event class must be previously imported in BHOM
#         - Update variables below according to your environment and preferences
#

# Set HCTM parameters
hctm_url=https://my-hctm-tenant.us1.controlm.com
hctm_name="Helix Control-M"

# Set BHOM parameters
bhom_url=https://my-bmc-helix-portal.com/events-service/api/v1.0/events
bhom_api_key=mybh0m12-1234-1234-1234-ap1k3y123456
bhom_class="ControlMAlert"

# Set HCTM to BHOM correspondence for the "severity" field
# HCTM : V (Very urgent), U (Urgent), R (Regular) | BHOM : CRITICAL, MAJOR, MINOR, WARNING, INFO, OK, UNKNOWN
sev_V="CRITICAL"
sev_U="MAJOR"
sev_R="MINOR"

# Send updates of existing alerts? (Y/N)
alert_updates="Y"

if [ $alert_updates == "N" ] ; then
   # If this is an alert update ("eventType" = U), exit
   if [ $2 == "U" ] ; then exit 0 ; fi
fi

# Declare array with all the alert field names (DO NOT MODIFY - using default field names for HCTM alerts)
field_names=("eventType" "id" "server" "fileName" "runId" "severity" "status" "time" "user" "updateTime" "message" "runAs" "subApplication" "application" "jobName" "host" "type" "closedByControlM" "ticketNumber" "runNo" "notes")

# START PROCESSING ALERT DATA

# Start JSON and add BHOM mandatory fields
hctm_tenant=`echo $hctm_url | cut -c 9-`
json_data="[ { \"class\" : \"$bhom_class\", \"location\" : \"$hctm_name\", \"source_identifier\" : \"$hctm_tenant\","

# Start creating url for the job link
job_link=$hctm_url/ControlM/#Neighborhood:

# Convert parameters to JSON format
num_fields=${#field_names[@]}
for i in ${!field_names[@]}; do
   field=${field_names[$i]}
   next_field=${field_names[$i+1]}
   if [ $i != $((num_fields-1)) ] ; then
      value=`echo $* | grep -oP "(?<=${field}: ).*(?= ${next_field}:)"`
      
      # Update some fields for BHOM compatibility
      case $field in
         id)
            # Change "id" field name to "alertId"
            field="alertId"
         ;;
         server)
            # Change "server" field name to "ctmServer"
            field="ctmServer"
            # Save "server" value in a variable (for the job link)
            ctm_server=$value
         ;;
         runId)
            # Add "runId" and "server" to the job link
            job_link=$job_link"id="$value"&ctm="$ctm_server
         ;;
         severity)
            # Convert "severity" format from HCTM to BHOM
            bhom_severity="sev_${value}"
            value=${!bhom_severity}
         ;;
         status)
            # Change "status" field name to "alertStatus"
            field="alertStatus"
         ;;
         time | updateTime)
            # Change "time" field name to "creation_time"
            if [ $field == "time" ] ; then field="creation_time" ; fi
            # Convert to Epoch time, in milisecs
            D="$value"
            value=`date -d "${D:0:8} ${D:8:2}:${D:10:2}:${D:12:2} +0000" "+%s%3N"`
         ;;
         user)
            # Change "user" field name to "ctmUser"
            field="ctmUser"
         ;;
         message)
            # Change "message" field name to "msg"
            field="msg"
         ;;
         jobName)
            # Add "jobName" to the final job link
            job_name="${value// /%20}"  # Replace spaces by "%20"
            job_link=$job_link"&name="$job_name"&direction=1&radius=3"  # Direction and radius can be customized
         ;;
         host)
            # Change "host" field name to "source_hostname"
            field="source_hostname"
            # Save "host" value in a variable (used to determine whether to include the job link)
            saved_host=$value
         ;;
         type)
            # Change "type" field name to "alertType"
            field="alertType"
         ;;
      esac
      text=`echo -ne "\"$field\" : \"$value\","`

   else
      # If last field ("notes"), capture until EOL
      value=`echo $* | grep -oP "(?<=${field}: ).*(?)"`
      # Change "notes" field name to "alertNotes"
      text=`echo -ne "\"alertNotes\" : \"$value\""`
      # Add link to job (only if "host" was not empty, meaning it is an alert related to a job)
      if [ ! -z "$saved_host" ] ; then
         text=$text", \"jobLink\" : \"$job_link\""
      fi  
      # Close JSON
      text=$text" } ]"
   fi
   json_data="$json_data $text"
done

# Set library path to solve curl error when Helix Control-M Agent is installed
# USE ONLY if you get the error: "curl: (48) An unknown option was passed in to libcurl"
# See https://bmcsites.force.com/casemgmt/sc_KnowledgeArticle?sfdcid=kA33n000000YHinCAG&type=Solution
# export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"

# Send alert data to BHOM
curl -X POST $bhom_url -H "Authorization: apiKey $bhom_api_key" -H 'Content-Type: application/json' -d "$json_data"

exit 0
