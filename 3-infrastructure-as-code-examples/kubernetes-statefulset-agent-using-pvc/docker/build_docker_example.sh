# This example is running the build command with parameters, login to aws and push the image to ECR .
# You need to change the parameters: 
#   1. image tag - compose of repo name: <number>.dkr.ecr.<region>.amazonaws.com/<name>:<image-tag>
#   1. endpoint, 
#   2. user, 
#   3. password
#   4. the agent image you want to install (taken from "ctm provision images Linux" cli)
sudo docker build -t 000000000000.dkr.ecr.us-west-2.amazonaws.com/repo-name:agent-tag --build-arg AAPI_END_POINT=https://endpoint-hostname:8443/automation-api --build-arg AAPI_USER=emuser --build-arg AAPI_PASS=password --build-arg AGENT_IMAGE_NAME=Agent_Image.Linux  . 

# aws login
sudo `aws ecr get-login --no-include-email`

# push tagged image to ECR
sudo docker push 000000000000.dkr.ecr.us-west-2.amazonaws.com/repo-name:agent-tag

# later on, the statefulset will use this image from ECR