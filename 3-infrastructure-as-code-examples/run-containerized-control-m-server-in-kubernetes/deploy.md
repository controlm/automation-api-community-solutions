# Deploying into Kubernetes

With the underlying Helm Chart and Container image created, we are almost ready to deploy everything into our kubernetes cluster. However, there are some steps required on the Control-M/Enterprise Manager that must be done first:

### Control-M/Enterprise Manager Setup

On the Control-M/Enterprise Manager that the containerized Control-M/Server will be connected to, the following steps must be done so that the Control-M/Server Deployment via Automation API can be performed:
1. Create the Control-M/Server image provisioning descriptor file on Control-M/Enterprise Manager.
  - Documentation on creating this file can be found in the BMC Control-M Online Documentation [here](http://documents.bmc.com/supportu/9.0.19/help/Main_help/en-US/index.htm#94860.htm)
  - For this example, the following deployment image descriptor file was created on the Control-M/Enterprise Manager:
    ```JSON
    {
      "OS": "Linux-x86_64",
      "Installers":
        [
          "DRCTV.9.0.19.100_Linux-x86_64.tar.Z"
        ]
    }
    ```
2. Add the Control-M/Server installation file to Control-M/Enterprise Manager AUTO_DEPLOY directory.
  - Documentation on obtaining the installation file, and where to place it on the Control-M/Enterprise Manager can be found in the BMC Control-M Online Documentation [here](http://documents.bmc.com/supportu/9.0.19/help/Main_help/en-US/index.htm#94859.htm)
  - In this case we need the Control-M/Server 9.0.19.100 Linux Tar install media as that is what is specified in the deployment image above.


### Database

A version of Oracle supported by version of Control-M/Server that will be deployed. (This example was tested with Oracle 12.1.0.1.0) In addition, the following information about the database is also necessary to have in order to perform the deployment:
  - hostname
  - port (if non-default)
  - Instance Name
  - DBA Username and Password
    - used to set up the Control-M/Server database at install time
  - Desired Database Owner Username (defaults to ctmuser)
  - Desired Database Owner Password

##### Other required information
  - The "datacenter" name that this Control-M/Server should be added to the Control-M/Enterprise Manager under
  - Automation API Endpoint (Ex: https://emhost:8443/automation-api)
  - Account to access Automation API with sufficient privileges to add the Control-M/Server
     - The password for this account is placed in the a k8s secret, see the deployment.yaml section of chart.md for [more information](./chart.md#deploymentyaml)


### Performing the deployment
With the required information from above on hand, the helm chart can be deployed using the below command:
```
helm upgrade $DEPLOY_NAME ./chart/k8s-ctms --install --name $DEPLOY_NAME --namespace $DEPLOY_NS --set image.repository=$CI_REGISTRY_IMAGE --set image.deploysecret=k8s-ctms-image-pull --set ctm.aapi_endpoint=$aapi_endpoint --set ctm.aapi_passwd_secret_name=aapi-k8s-pw --set ctm.aapi_passwd_secret_key=mypass --set db.instance=$db_instance --set db.host=$db_host --set db.port=1521 --set db.dba_pass=$dba_pass --set ctm.datacenter=$DEPLOY_NAME --set db.dbo_user=$dbo_user
```
In the above example command, the following environment variables are used. (In the case of testing this example, these environment variables are stored as Gitlab CI variables and set by the Gitlab CI runner)  

| Environment Variable | Usage                                                                                                        |
|----------------------|--------------------------------------------------------------------------------------------------------------|
| $DEPLOY_NAME         | Sets the name of the deployment in Helm Tiller                                                               |
|                      |Sets the Datacenter name that is used to identify the Control-M/Server in the Control-M/Enterprise Manager    |
| $DEPLOY_NS           | Sets the Kubernetes Namespace into which deploy the Control-M/Server                                         |
| $CI_REGISTRY_IMAGE   | Sets the base Container Registry host/path                                                                   |
| $aapi_endpoint       | Sets the endpoint used to connect to Automation API                                                          |
| $db_instance         | Sets the Oracle Instance name                                                                                |
| $db_host             | Sets the Oracle Hostname                                                                                     |
| $dba_pass            | Sets the Oracle DBA Password (This value is masked when using Gitlab's CI and the masked option is selected) |
| $dbo_user            | Sets the Database Owner Username                                                                             |

A successful deployment would result in output similar to (Note that the external IP of the LoadBalancer has been changed to an example value as this will be different for each environment):
```
LAST DEPLOYED: Mon Jul 29 16:13:38 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/Deployment
NAME      DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
k8s-ctms  1        1        1           1          2s

==> v1/Pod(related)
NAME                      READY  STATUS   RESTARTS  AGE
k8s-ctms-f88dd4666-stxr7  1/1    Running  0         2s

==> v1/ConfigMap
NAME                DATA  AGE
k8s-ctms-configmap  1     2s

==> v1/Service
NAME      TYPE          CLUSTER-IP     EXTERNAL-IP  PORT(S)                                       AGE
k8s-ctms  LoadBalancer  10.105.203.66  **AAA.BB.C.DD**  7005:30372/TCP,2369:30693/TCP,2370:31105/TCP  2s


NOTES:
To see the pod(s) deployed, run:
kubectl get pods --namespace default -l "app.kubernetes.io/name=k8s-ctms,app.kubernetes.io/instance=k8s-ctms"
```

To check that the Control-M/Server was added to the Control-M/Enterprise Manager:
```
$ ctm config servers::get
[
  {
    "name": "k8s-ctms",
    "host": "**AAA.BB.C.DD**",
    "state": "Up",
    "message": "Connected"
  }
]
```
Note that the `host` value in the above output matches the LoadBalancer's External IP, as that is was is used by the Control-M/Enterprise Manager to connect to the Control-M/Server.
