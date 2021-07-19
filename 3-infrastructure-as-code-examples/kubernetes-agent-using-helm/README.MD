# Best Practices for using Control-M to run a pod to completion in a Kubernetes-based cluster using a Helm chart

| Objective             | Corresponding CLI command                                  |
|-----------------------|------------------------------------------------------------|
| Deploy the Agent Locally     | ```helm upgrade -i control-m-agent ./control-m-agent -n controlm -f values.yaml``` |
| Get details                  | ```kubectl describe job “job name” This returns the pod name.``` |
| Monitor the job’s pod        | ```kubectl get pod “pod name”```                                 |
| Get the job output           | ```kubectl logs “pod name”```                                    |