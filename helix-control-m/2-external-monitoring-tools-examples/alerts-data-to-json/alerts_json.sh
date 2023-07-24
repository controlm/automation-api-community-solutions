#!/bin/bash
#
# BMC Helix Control-M - External Alert Management service
#
# Sample script to record alert data in JSON format
#

# Set the directory and file name for the alerts file
alerts_dir="./alert_data"
alerts_file="alerts_json.txt"

# Declare array with all the alert field names
# (Leave as is to use the default fields for HCTM alerts)
field_names=("eventType" "id" "server" "fileName" "runId" "severity" "status" "time" "user" "updateTime" "message" "runAs" "subApplication" "application" "jobName" "host" "type" "closedByControlM" "ticketNumber" "runNo" "notes")

# Start JSON
json_data=`echo -ne "{ \"alertFields\" : ["`

# Convert script arguments to JSON
num_fields=${#field_names[@]}
for i in ${!field_names[@]}; do
   name1=${field_names[$i]}
   name2=${field_names[$i+1]}
   if [ $i != $((num_fields-1)) ] ; then
      value=`echo $* | grep -oP "(?<=${name1}: ).*(?= ${name2}:)"`
      text=`echo -ne "{\"$name1\" : \"$value\"},"`
   else
      # If last field, capture until EOL, don´t add last "," and close JSON
      value=`echo $* | grep -oP "(?<=${name1}: ).*(?)"`
      text=`echo -ne "{\"$name1\" : \"$value\"} ] } \n"`
   fi
   json_data="$json_data $text"
done

# Save alert data in a file 
echo "$json_data" >> $alerts_dir/$alerts_file

exit 0