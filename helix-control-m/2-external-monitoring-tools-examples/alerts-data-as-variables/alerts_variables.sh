#!/bin/bash
#
# BMC Helix Control-M - External Alert Management service
#
# Sample script to extract alert data into variables
#

# Set the directory and file name for the alerts file
alerts_dir="./alert_data"
alerts_file="alerts_variables.txt"

# Declare array with all the alert field names
# (Leave as is to use the default fields for HCTM alerts)
field_names=("eventType" "id" "server" "fileName" "runId" "severity" "status" "time" "user" "updateTime" "message" "runAs" "subApplication" "application" "jobName" "host" "type" "closedByControlM" "ticketNumber" "runNo" "notes")

# Parse fields names and values
num_fields=${#field_names[@]}
for i in ${!field_names[@]}; do
   name1=${field_names[$i]}
   name2=${field_names[$i+1]}
   if [ $i != $((num_fields-1)) ] ; then
      value=`echo $* | grep -oP "(?<=${name1}: ).*(?= ${name2}:)"`
   else
      # if last field, capture until EOL
      value=`echo $* | grep -oP "(?<=${name1}: ).*(?)"`
   fi
   # Create variables with their extracted values
   declare ${field_names[$i]}="$value"
done

# Use the variables as needed, e.g.
echo "$time | $id | $severity | $runId | $application | $jobName | $host | $message" >> $alerts_dir/$alerts_file

exit 0