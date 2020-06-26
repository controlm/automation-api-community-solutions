# This build example is tagging the container according to ECR usage
# You need to change the parameters: endpoint, user, password and the agent image you want to install (taken from "ctm provision images Linux" cli)
sudo docker build -t 000000000000.dkr.ecr.us-west-2.amazonaws.com/repo-name:agent-tag --build-arg AAPI_END_POINT=https://endpoint-hostname:8443/automation-api --build-arg AAPI_USER=emuser --build-arg AAPI_PASS=password --build-arg AGENT_IMAGE_NAME=Agent_19.Linux  . 
