# Creating the Helm Chart

A Helm Chart provides a quick and easy way to deploy software to a Kubernetes cluster. The below code example shows creating a chart using the helm cli client:

```
mkdir chart && cd chart
helm create k8s-ctm
```

This creates the base chart structure (see below) that we will modify to fit our needs.

```
k8s-ctm
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

### values.yaml

The first file we need to modify is ```k8s-ctm/values.yaml``` as the default chart has some values that are unsuited for our needs.

Since we aren't deploying nginx with this chart, the default image.repository value needs to change
```
image:
  repository: nginx
  tag: stable
  pullPolicy: IfNotPresent
```

It can be set to ```""``` to force setting at deploy time, or set the default value to your internal container registry.

At the bottom of ```k8s-ctm/values.yaml``` we'll add a section for defining our Control-M specific parameters:

```
ctm:
  povisionImage: Agent9182.Linux
  aapi_endpoint: ""
  aapi_user: emuser
  datacenter: ""
  host_group: ""
  agent_port: 7006
```

Lastly in the values.yaml file, we will change ```replicaCount: 1``` to be
```
autoscale:
  min: 1
  max: 5
  cpu: 70
```
So that we can make use of horizontal auto-scaling.

(Note: We have removed the ingress and service sections from the values.yaml and templates directory as they aren't needed in this example.)

### deployment.yaml

Moving to the ```k8s-ctm/templates/deployment.yaml``` file now, we can begin modifying it to allow auto-scaling.

First, we'll need to remove the following line from the `spec` section:
```
  replicas: {{ .Values.replicaCount }}
```

Instead of a static number of replicas, the Horizontal Pod Autoscaler discussed later in this document will handle changing the replica count accounting to the CPU load.

Under the containers section, we'll set the port to the ctm.agent_port value, and assign environment variables to be used by the container image:

```
ports:
  - containerPort: {{ .Values.ctm.agent_port }}
env:
- name: CTM_USER
  value: {{ .Values.ctm.aapi_user }}
- name: CTM_SERVER
  value: {{ .Values.ctm.datacenter }}
- name: CTM_HOST
  value: {{ .Values.ctm.aapi_endpoint }}
- name: IMAGE
  value: {{ .Values.ctm.povisionImage }}{{ if .Values.ctm.host_group }}
- name: HOST_GROUP
  value: {{ .Values.ctm.host_group }}{{ end }}
- name: NAMESPACE
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: metadata.namespace
- name: INSTANCE
  value: {{ .Release.Name }}
- name: NAME
  value: {{ .Chart.Name }}
```

To securely provide a password, we will use a Kubernetes Secret, and provide the secret name and key to the chart when deployed. To create the secret:

```
kubectl create secret generic aapi-k8s-pw --from-literal=mypass='b6sS7r#Jk&6+'
```

This secret will be used when setting the following values at deploy time:

[values.yaml](./chart/k8s-ctm/values.yaml):

```
  aapi_passwd_secret_name: ""
  aapi_passwd_secret_key: ""
```

[deployment.yaml](./chart/k8s-ctm/templates/deployment.yaml):

```
- name: CTM_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.ctm.aapi_passwd_secret_name }}
      key: {{ .Values.ctm.aapi_passwd_secret_key }}
```

### hpa.yaml

Dynamically scaling the pod requires the following:
1. A HorizontalPodAutoscaler defined that looks at one or more metrics of the pod to determine if the pod should be scaled up or down
2. If using the built in CPU or Memory metrics, resource requests and/or limits must be defined either when deploying the chart (ie: `--set resources.requests.cpu=250m` or `--set resources.requests.memory=2Gi` or `--set resources.requests.cpu=250m,resources.requests.memory=2Gi`) or with a default defined in the Kubernetes namespace via a [LimitRange](https://kubernetes.io/docs/concepts/policy/limit-range/) policy.

In our example we have defined a LimitRange that sets a default cpu request of 250m for any pod deployed in this namespace. (A cpu request of 250m in kubernetes is equivilent to 1/4 of a CPU core, or thread if running on baremetal with hyperthreading. For more information about this see the Kubernetes documentation [here](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/))
