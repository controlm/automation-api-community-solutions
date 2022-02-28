# Dynamic Control-M agent on Google Cloud Compute Engine instances
# WORK IN PROGRESS
Control-M orchestrates application workflows to ensure critical business services operate efficiently and according to expected service levels. When errors do occur, problems can be analyzed and corrected quickly, with easy access to failure information such as logs and a consistent set of tools for manipulating workflow components. Taking a Jobs-as-Code approach enables developers and engineers to build workflows and other artifacts using JSON or Python and to interact with Control-M via Automation API which provides RESTful web services and a node.js command line interface. 

The material in this folder is one example of how Control-M agents can be dynamically created and decommissioned in a GCE environment. The approach describes using an instance template to create a VM Instance from a template (via the gcloud cli or GCP Console) and have the Control-M agent automatically deployed on each instance.

A similar approach can be taken with almost every other form of dynamic, virtual infrastructure including Azure, AWS, IBM Cloud, Oracle Cloud and OpenStack, Docker, and Kubernetes. See other folders in this repository for examples.

This content assumes you are familiar with Control-M administration, Google Cloud Platform and the Compute Engine service.

## Approach
An Instance template is created with the attributes required to create an appropriate virtual machine that can host a Control-M agent. When a VM instance is created, a bootstrap script executes that registers with a Control-M environment, joins a hostgroup, and begins running work. 

The target Control-M environment and hostgroup are specified with VM labels so that the process is completely dynamic. If your organization has multiple Control-M environments such as test, QA and Prod, for example, the same template can be used to deploy an agent for any of those environments. By specifying the proper label values, the new instance(s) will join the desired environment.

### Implementation
When a virtual machine is created, labels and a service account are attached to it. During system startup, the bootstrap script (based on [gc-bootstrap.sh.sample](https://github.com/controlm/automation-api-community-solutions/blob/master/3-infrastructure-as-code-examples/manage-workload-on-ec2/rc.AWS_Agent_sample)) retrieves specific labels and uses the values as "lookup keys" to retrieve Google Secret Manager secrets. The permission to retrieve those secrets is granted by the service acocunt assigned to the VM.  

The retrieved values are used to connect to a Control-M environment with the appropriate credentials.

+ **Google Virtual Machine labels**

   **ctmenvironment**: This value is used to retrieve endpoint and credentials information. It's intended to be a logical description of the environment such as ctmprod, ctmqa, etc. but the only requirement is that the credentials information can be retrieved using this value as a prefix.    

   **ctmhostgroup**: This is the hostgroup this agent will join. Since these EC2 instances are assumed to be transient, you would not want to use host names in any jobs, thus the need for a hostgroup.    

+ **Config and Secrets repository**  
  If, for example, the **ctmenvironment** tag value is "ctmprod", the following values are retrieved:  
  **ctmprod-url**: The Control-M Automation API endpoint  

  **ctmprod-user**: Control-M username for logging in via Automation API    

  **ctmprod-password**: The password for the Control-M user    

  **ctmprod-server**: The Control-M Server name

  **ctmprod-agentuser**: The Linux user under which the Control-M agent was installed/provisioned. This value is normally configured by the installation process in the sample rc.agent-user script but since a generic script is being used here, this secret enables the initialization script to determine the agent user dynamically. PLEASE NOTE: This has not yet been provided  

When the instance is stopped, the same rc script removes the agent from the hostgroup it joined and deletes the agent from the Control-M server.

## Video tutorial
The entire process is demonstrated in this [**video**](//https://youtu.be/nTLdA0U2tgU).

You can find the latest Control-M Automation API documentation, including a programming guide, on the [**project web page**](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Getting+Started+Guide).
