# Kuberentes Example - Control-M Agent in Persistant mode

## Intro
In this example we will focus on creating a Kubernetes <b>POD</b> with Control-M agent in container. 
During container start, Control-M Agent will register itself automatically into Control-M Enterprise Manager. 
Additionally, during Container graceful stop, Control-M Agent will try to disconnect and unregister from Control-M Enterprise Manager. 

Control-M Agent will use specified port for communication. The connection mode will be set to persistant, agent will initiate the connection to server. This scenario makes that there is no need to open any port on K8S cluster nor need to create and maintain any objects like LoadBalancers (of course in different scenario/architecute such objects would be needed, just for single agent with no HA it is not required).

## Image files
Docker images files are placed in image folder. Sample script to build the image is in build.sh or you can use the command below:

```
docker build --build-arg CTMHOST=<name-or-ip-of-your-em-here> --build-arg USER=<your-user> --build-arg PASSWORD=<your-password> --tag ctm/agent/rt:2.0  .
```

## Deployment file
Examples of deployment files are :
* ctmagent_rt2.yaml - this file is example of pod definition with 1 container that uses previously defined image. 
* ctmagent_rt2-deployment.yaml - similar to the example above, but using a deployment method with replicas count=1



  #   b|backofflimit      default is 0