
# How to Deploy a Control-M Agent on a Managed Kubernetes Cluster

## Running Control-M Workloads in Kubernetes
This readme describes how to run Control-M workloads in a Managed Kubernetes clusters like Amazon Elastic Kubernetes Service (EKS). The information in this document focuses on the scenario of running a pod to completion with a Control-M/Agent running within the cluster. 

Follow this link for the full documentation and perform this demo. 

## Methodological Approach

The Agent pod is to run as a StatefulSet, so that the hostname will be identified consistently across pod shutdown and startup. This enables Control-M/Server to uniquely identify the Control-M/Agent continuously and consistently.

The pod uses a persistent volume, so that job data and Control-M/Agent state are kept during shutdown and startup.

The connection between the Control-M/Agent and Control-M/Server is set up as a persistent connection that is initiated by the Agent. This was designed to avoid exposing the Kubernetes cluster to outside connections.


----------|

## Process Steps
A typical process of deploying Control-M/Agent on Kubernetes consists of the following steps:

- [Step 1: Create a Control-M/Agent image](#step-1-create-a-control-magent-image)
- [Step 2: Push image to remote repository](#step-2-add-kubernetes-job-type-to-application-integrator)
- [Step 3: Provision EKS Cluster](#step-3-create-persistent-storage-and-run-the-agent)
- [Step 4: Update Kubeconfig to point to EKS Cluster](#step-4-verify-permissions)
- [Step 5: Create Persistent volume and volume claim](#step-5-run-control-m-jobs)
- [Step 6: Deploy statefulset](#step-5-run-control-m-jobs)
- [Step 7: Run kubernetes job with Control-M](#step-5-run-control-m-jobs)


To see a detailed documentation of this process, Please follow this link. 
