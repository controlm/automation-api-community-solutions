#!/bin/bash
#
# BMC Helix Control-M - External Alert Management service
#
# Sends Helix Control-M alerts as SNMP (v1) traps
#
# Author  : David Fernandez (david_fernandez@bmc.com)
# Version : 1.0 (05/02/2024)
#
# Notes : - Requires "snmptrap" (from "net-snmp-utils" package - see http://www.net-snmp.org) 
#         - The MIB file (BMC-CONTROLMEM-MIB) must be loaded in the SNMP destination host
#

# SNMP destination host(s)
# Use commas (,) as delimiter for multiple hosts, and colon (:) to use a specific port (default 162)
# Example: myhost1,myhost2:2001,192.168.1.37
destination=192.168.1.37

# SNMP base OID for Alerts (as defined in BMC-CONTROLMEM-MIB) - DO NOT MODIFY
base_oid=1.3.6.1.4.1.1031.9.1

# Send updates of existing alerts? (Y/N)
alert_updates="Y"

# Declare array with all the alert field names
# Leave as is to use the default fields for HCTM alerts
field_names=("eventType" "id" "server" "fileName" "runId" "severity" "status" "time" "user" "updateTime" "message" "runAs" "subApplication" "application" "jobName" "host" "type" "closedByControlM" "ticketNumber" "runNo" "notes")

# If alert updates are not needed, exit if "call_type" = "U"
if [ $alert_updates == "N" ] ; then
   if [ $2 == "U" ] ; then exit 0 ; fi
fi

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
   # Create the list of SNMP values to pass as parameters
   # adding OID + type (s = string) + value
   field_number=$((i+1))
   snmp_values=$snmp_values" "$base_oid.$field_number" s "\"$value\"
done

# Send the SNMP trap(s)
for i in ${destination//,/ } ; do
   bash -c "snmptrap -v 1 -c public $i $base_oid '' 6 10 '' $snmp_values"
done
