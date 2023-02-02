#!/bin/bash
#
# BMC Helix Control-M - External Alert Management service
#
# This script is executed each time an alert is received, and triggers all scripts in a predefined path, passing all parameters received to each of them.
#
# Notes : - The scripts are executed as background processes.
#         - Only scripts with the ".sh" extension are executed.
#

# Set the dir which stores the alert scripts (relative to the path where this script resides)
alert_scripts_dir="./alert_scripts"

# Run every script in that dir, passing all parameters
for f in $alert_scripts_dir/*.sh ; do
   bash "$f" $* &
done

exit 0