#!/bin/bash

# Create secrets for Control-M "ctmprod" environment
# URL of the Automation API endpoint
printf "https://ip-172-31-50-204.us-west-2.compute.internal:8443/automation-api" | gcloud secrets create ctmprod-url --data-file=- 
printf "https://smprod.ctmdemo.com:8443/automation-api" | gcloud secrets versions add ctmprod-url --data-file=-
# Control-M username
printf "apiuser" | gcloud secrets create ctmprod-user --data-file=-

# Control-M password
printf "2Mzpah7msYUA94ZyzPztqBrn" | gcloud secrets create ctmprod-password --data-file=-

# Agent username
printf "ctmagent" | gcloud secrets create ctmprod-agentuser --data-file=-

# Control-M Server name
printf "smprod" | gcloud secrets create ctmprod-server --data-file=-

printf "https://smprod.ctmdemo.com:8443/automation-api" | gcloud secrets versions add ctmprod-url --data-file=-