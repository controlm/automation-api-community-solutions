# Creating the Helm Chart

A Helm Chart provides a quick and easy way to deploy software to a Kubernetes cluster. The below code example shows creating a chart using the helm cli client:

```
mkdir chart && cd chart
helm create k8s-ctms
```

This creates the base chart structure (see below) that we will modify to fit our needs.

```
k8s-ctms
|-- Chart.yaml
|-- charts
|-- templates
|   |-- NOTES.txt
|   |-- _helpers.tpl
|   |-- deployment.yaml
|   |-- ingress.yaml
|   `-- service.yaml
`-- values.yaml
```

### Values.yaml

The first file we need to modify is ```k8s-ctms/values.yaml``` as the default chart has some values that are unsuited for our needs.

Since we aren't deploying nginx with this chart, the default image.repository value needs to change
```
image:
  repository: nginx
  tag: stable
  pullPolicy: IfNotPresent
```

It can be set to ```""``` to force setting at deploy time, or set the default value to your internal container registry.

Because the Control-M/Server will be connected to a Control-M/Enterprise Manager that is outside of the Kubernetes cluster, we will change the default `service` section in `k8s-ctms/values.yaml` file to have a `type` of `LoadBalancer` so that a service is defined with an IP Address that is routable outside of the cluster.

At the bottom of ```k8s-ctms/values.yaml``` we'll add a section for defining our Control-M specific parameters:

```
ctm:
  datacenter: ""
  povisionImage: Server919100.Linux
  aapi_endpoint: ""
  aapi_user: emuser
  AgentToServerPort: 7005
  ConfigurationAgentPort: 2369
  ControlMEMTcpIpPort: 2370
  aapi_passwd_secret_name: ""
  aapi_passwd_secret_key: ""
```

Lastly in the values.yaml file, we add the following section to define the necessary database parameters:
```
db:
  host: ""
  port: ""
  vendor: Oracle
  instance: "ORCL.local"
  dba_user: "SYSTEM"
  dba_pass: ""
  dbo_user: "ctmuser"
  dbo_pass: "Tester01"
```
(Note: We have removed the ingress and service sections from the values.yaml and templates directory as they aren't needed in this example.)

### deployment.yaml

Moving to the ```k8s-ctms/templates/deployment.yaml``` file now, we can begin modifying it to suit our needs.


Under the containers section, we'll use the port values set in in the `ctm` section of the `values.yaml` file to define the ports that will be opened to Control-M/Server Container:


```
ports:
- name: agent-to-server
  containerPort: {{ .Values.ctm.AgentToServerPort }}
  protocol: TCP
- name: config-agent
  containerPort: {{ .Values.ctm.ConfigurationAgentPort }}
  protocol: TCP
- name: control-m-em
  containerPort: {{ .Values.ctm.ControlMEMTcpIpPort }}
  protocol: TCP
```

To securely provide a password, we will use a Kubernetes Secret, and provide the secret name and key to the chart when deployed. To create the secret:

```
kubectl create secret generic aapi-k8s-pw --from-literal=mypass='b6sS7r#Jk&6+'
```

This secret will be used when setting the following values at deploy time:

[values.yaml](./chart/k8s-ctms/values.yaml):

```
  aapi_passwd_secret_name: ""
  aapi_passwd_secret_key: ""
```

[deployment.yaml](./chart/k8s-ctms/templates/deployment.yaml):

```
- name: CTM_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.ctm.aapi_passwd_secret_name }}
      key: {{ .Values.ctm.aapi_passwd_secret_key }}
```

### configmap.yaml

To dynamically define the JSON file needed for Control-M Automation API's [Server provisioning service](https://docs.bmc.com/docs/display/workloadautomation/API+Services+-+Provision+service+configuration) as ConfigMap is used. Using the templating provided by Helm, the values set at the time the chart is deployed are put in to the template configmap file: [configmap.yaml](./chart/k8s-ctms/templates/configmap.yaml)
- Note: The hostname under the configuration section of the configmap cannot be determined until the pod has initialized as this is host name that the Control-M/Server processes will bind. The `10.10.10.10` address seen the configmap.yaml file is a dummy address that is replaced with the correct name at execution time.

### service.yaml

So that the Control-M/Server can be accessed by a single name, even if the pod restarts or dies, and is accessible outside of the kubernetes cluster, as Service is defined in the [service.yaml](./chart/k8s-ctms/templates/service.yaml) file.

The import sections of note in this file are:
1. The ports are defined here again, similarly to how they were defined in the [deployment.yaml](./chart/k8s-ctms/templates/deployment.yaml) file. This is so that the service will route connections on those ports, to the same ports on the Container where the Control-M/Server is running.
2. So that Kubernetes knows which pod/container to map the service to the `selector` section of the `service` definition much match the `labels` under `spec.template.metadata.labels` in the `deployment` definition.

Ex:
 - deployment.yaml
   ```
   apiVersion: apps/v1
   kind: Deployment
   ...
   spec:
   ...
     template:
       metadata:
         labels:
           app.kubernetes.io/name: {{ .Release.Name }}
           app.kubernetes.io/instance: {{ .Release.Name }}
   ```
 - service.yaml
   ```
   apiVersion: v1
   kind: Service
   ...
   spec:
     selector:
       app.kubernetes.io/name: {{ .Release.Name }}
       app.kubernetes.io/instance: {{ .Release.Name }}
   ```
