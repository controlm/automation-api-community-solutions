#!/bin/bash

# Create secrets for Control-M "ctmprod" environment
# URL of the Automation API endpoint
url-secret='"https://ip-172-31-50-204.us-west-2.compute.internal:8443/automation-api"'
aws secretsmanager create-secret --region us-west-2 --name ctmprod-url \
    --description "Control-M URL" \
    --secret-string ${url-secret}

# Control-M Server
aws secretsmanager create-secret --region us-west-2 --name ctmprod-server \
    --description "Control-M Server name" \
    --secret-string "smprod"

# Control-M username
aws secretsmanager create-secret --region us-west-2 --name ctmprod-user \
    --description "Control-M user name" \
    --secret-string "apiuser"

# Control-M password
aws secretsmanager create-secret --region us-west-2 --name ctmprod-password \
    --description "Control-M password" \
    --secret-string "2Mzpah7msYUA94ZyzPztqBrn"

# Agent username
aws secretsmanager create-secret --region us-west-2 --name ctmprod-agentuser \
    --description "Control-M Agent username" \
    --secret-string "ctmagent"

aws secretsmanager update-secret --secret-id ctmprod-url --region us-west-2 --secret-string '"https://smprod.ctmdemo.com:8443/automation-api"'