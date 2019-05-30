#!/bin/bash

# Version 1.2
# Created by Tijs Mont�
# Created on 15-February-2019
#
# This script pulls the HEAD -1 version of a jobs-as-code json file and the deploy descriptor file.
# Usage: compare_with_previous.sh <ENDPOINT> <USER> <PASSWORD>


filename=folder-check-sample.json
temp_file="previous_$filename"
current_deploydesciptor="DeployDescriptor.json"
previous_deploydesciptor="previous_"$current_deploydesciptor
endpoint=$1
user=$2
password=$3

git show HEAD^:./$filename > $temp_file
git show HEAD^:./$current_deploydesciptor > $previous_deploydesciptor

python3 folder_check.py -c $filename -o $temp_file $mode -e $endpoint -u $user -p $password $4 $5 $6 $7 $8
#rm $temp_file
#rm $previous_deploydesciptor