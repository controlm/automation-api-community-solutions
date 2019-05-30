#!/bin/bash

CTMPods = $(kubectl get pods| grep controlm-agent)
CTMEndpoint = $(kubectl get secret ctmenv-ctmprod -o yaml | grep endpoint.secret: | cut -d' ' -f 4 | base64 --decode)
CTMUser = $(kubectl get secret ctmenv-ctmprod -o yaml | grep username.secret: | cut -d' ' -f 4 | base64 --decode)
CTMPswd = $(kubectl get secret ctmenv-ctmprod -o yaml | grep password.secret: | cut -d' ' -f 4 | base64 --decode)

echo Agents found $CTMPods
echo $CTMEndpoint $CTMUser $CTMPswd