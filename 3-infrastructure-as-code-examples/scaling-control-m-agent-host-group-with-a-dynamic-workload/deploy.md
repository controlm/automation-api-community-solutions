# Deploying into Kubernetes

With the underlying Helm Chart and Container image created, we are almost ready to deploy everything into our kubernetes cluster. However, there are some steps required on the Control-M/Enterprise Manager that must be done first:

### Control-M/Enterprise Manager Setup

On the Control-M/Enterprise Manager that the containerized Control-M/Agent will be connected to, the following steps must be done so that the Control-M/Agent Deployment via Automation API can be performed:
1. Create a custom Control-M/Agent image provisioning descriptor file on Control-M/Enterprise Manager.
  - Documentation on creating this file can be found in the BMC Control-M Online Documentation [here](http://documents.bmc.com/supportu/9.0.19/help/Main_help/en-US/index.htm#94860.htm)
  - For this example, the following deployment image descriptor file was created on the Control-M/Enterprise Manager:
    ```JSON
    {
      "OS": "Linux-x86_64",
      "Installers":
        [
          "DRKAI.9.0.18.200_Linux-x86_64.tar.Z"
        ]
    }
    ```
2. Add the Control-M/Agent installation file to Control-M/Enterprise Manager AUTO_DEPLOY directory.
  - Documentation on obtaining the installation file, and where to place it on the Control-M/Enterprise Manager can be found in the BMC Control-M Online Documentation [here](http://documents.bmc.com/supportu/9.0.19/help/Main_help/en-US/index.htm#94859.htm)
  - In this case we need the Control-M/Agent 9.0.18.200 Linux Tar install media as that is what is specified in the deployment image above.


##### Other required information
  - The "datacenter" name of the Control-M/Server is already added under the Control-M/Enterprise Manager and will be used to schedule job to the Control-M/Agent (or hostgroup)
  - Automation API Endpoint (Ex: https://emhost:8443/automation-api)
  - Account to access Automation API with sufficient privileges to add the Control-M/Server
     - The password for this account is placed in the a k8s secret, see the deployment.yaml section of chart.md for [more information](./chart.md#deploymentyaml)
  - The name of the Control-M hostgroup to create and add the autoscaling Agent pods to.
     - Jobs should be scheduled against this name as the individual pods are ephemeral, but the hostgroup is persistent

##### Optional information
  - If the Control-M/Server's local interface name (hostname/IP address that Control-M/Server processes will bind to) should be overridden
    - If so, to what value

### Performing the deployment
With the required information from above on hand, the helm chart can be deployed using the below command:
```
helm upgrade $DEPLOY_NAME ./chart/k8s-ctm --install --debug --namespace $DEPLOY_NS --set image.repository=$CI_REGISTRY_IMAGE --set ctm.overrideCTMSHOST=$ctmsoverride --set image.tag=$CI_COMMIT_TAG --set image.deploysecret=${DEPLOY_NAME}-image-pull-${CI_COMMIT_TAG} --set ctm.aapi_endpoint=$aapi_endpoint --set ctm.datacenter=$datacenter --set ctm.host_group=$DEPLOY_NAME --set ctm.aapi_passwd_secret_name=aapi-k8s-pw --set ctm.aapi_passwd_secret_key=mypass
```
In the above example command, the following environment variables are used. (In the case of testing this example, these environment variables are stored as Gitlab CI variables and set by the Gitlab CI runner)  

| Environment Variable | Usage                                                                                                        |
|----------------------|--------------------------------------------------------------------------------------------------------------|
| $DEPLOY_NAME         | Sets the name of the deployment in Helm Tiller                                                               |
|                      | Sets the name of the Control-M Hostgroup that the Agents are added under
| $datacenter          | Sets the Datacenter name that is used to identify the Control-M/Server that will schedule jobs to these Control-M/Agent(s)   |
| $DEPLOY_NS           | Sets the Kubernetes Namespace into which deploy the Control-M/Agent(s)                                       |
| $CI_REGISTRY_IMAGE   | Sets the base Container Registry host/path                                                                   |
| $CI_COMMIT_TAG       | Sets the Container tag to deploy                                                                             |
| $aapi_endpoint       | Sets the endpoint used to connect to Automation API                                                          |
| $ctmsoverride        | Sets the override name, that Control-M/Server processes should bind to                                       |

A successful deployment would result in output similar to:
```
Release "k8s-ctma" has been upgraded. Happy Helming!
LAST DEPLOYED: Mon Jul 29 18:02:16 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/Service
NAME      TYPE       CLUSTER-IP  EXTERNAL-IP  PORT(S)  AGE
k8s-ctma  ClusterIP  None        <none>       <none>   55m

==> v1/Deployment
NAME      DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
k8s-ctma  3        3        3           3          55m

==> v1/HorizontalPodAutoscaler
NAME      REFERENCE            TARGETS  MINPODS  MAXPODS  REPLICAS  AGE
k8s-ctma  Deployment/k8s-ctma  0%/90%   1        5        3         55m

==> v1/Pod(related)
NAME                      READY  STATUS   RESTARTS  AGE
k8s-ctma-787f97c69-56qz2  1/1    Running  0         61s
k8s-ctma-787f97c69-ns8b2  1/1    Running  0         84s
k8s-ctma-787f97c69-s5d7s  1/1    Running  0         45s


NOTES:
To see the pod(s) deployed, run:
kubectl get pods --namespace default -l "app.kubernetes.io/name=k8s-ctm,app.kubernetes.io/instance=k8s-ctma"
```

To check that the Control-M/Agents and Hostgroup were added successfully:
```
$ ctm config server:hostgroups::get k8s-ctms
[
  "k8s-ctma"
]

$ ctm config server:hostgroup:agents::get k8s-ctms k8s-ctma
[
  {
    "host": "192.167.0.62"
  },
  {
    "host": "192.167.3.54"
  },
  {
    "host": "192.167.2.112"
  }
]
```
Note that the IP addresses seen in the above output are from the Kubernetes PodCIDR range, 192.167.0.0/16 in this example, and are not accessible outside of the Kubernetes cluster.
