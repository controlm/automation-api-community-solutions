# Dynamic Control-M agent on EC2 instances 
Control-M orchestrates application workflows to ensure critical business services operate efficiently and according to expected service levels. When errors do occur, problems can be analyzed and corrected quickly, with easy access to failure information such as logs and a consistent set of tools for manipulating workflow components. Taking a Jobs-as-Code approach enables developers and engineers to build workflows and other artifacts using JSON or Python and to interact with Control-M via Automation API which provides RESTful web services and a node.js command line interface. 

The material in this folder is one example of how Control-M agents can be dynamically created and decommissioned in an AWS environment. The approach describes building an Amazon Machine Image (AMI) that can then be used to launch EC2 instances however you desire (via the AWS cli, AWS Console, dynamically by AWS via Auto-Scaling) and have the Control-M agent automatically deployed on each instance.

A similar approach can be taken with almost every other form of dynamic, virtual infrastructure including Azure, Google Cloud, IBM Cloud, Oracle Cloud and OpenStack, Docker, and Kubernetes.

## Approach
An AMI is built with all the pre-requisites installed on the image. When an EC2 instance based on that AMI is launched, the instance registers with a Control-M environment, joins a hostgroup, and begins running work. It's assumed you are familiar with Control-M administration, AWS and the EC2 service.

The target Control-M environment and hostgroup are specified with EC2 instance tags so that the process is completely dynamic. If your organization has multiple Control-M instances such as test, QA and Prod, for example, the same AMI can be used to deploy an agent for any of those environments. By specifying the proper tag values, the new instance(s) will join the desired environment(s).

### Implementation
When an EC2 instance is launched, instance tags and an IAM role are attached to it. During system startup, the initialization script (based on [rc.AWS_Agent_sample](https://github.com/controlm/automation-api-community-solutions/blob/master/3-infrastructure-as-code-examples/manage-workload-on-ec2/rc.AWS_Agent_sample)) retrieves specific tags and uses them as "lookup keys" to retrieve information from a vault. In this example, AWS Secrets Manager is used and the ability to access those secrets is based on the IAM role assigned to the EC2 instance.  

The retrieved values are used to connect to a Control-M environment with the appropriate credentials.

+ **AWS Instance Tags**

   **ctmenvironment**: This value is used to retrieve endpoint and credentials information. It's intended to be a logical description of the environment such as ctmprod, ctmqa, etc. but the only requirement is that the credentials information can be retrieved using this value as a prefix.    

   **ctmhostgroup**: This is the hostgroup this agent will join. Since these EC2 instances are assumed to be transient, you would not want to use host names in any jobs, thus the need for a hostgroup.    

   **ctmserver**: The Control-M server name. This could have been a part of the credentials instead of a tag but if the target Control-M environment consists of several Control-M servers, specifying this as an instance tag reduces the number of credential "packages" required.   

+ **Config and Secrets repository**  
  If, for example, the **ctmenvironment** tag value is "ctmprod", the following values are retrieved:  
  **ctmprod-url**: The Control-M Automation API endpoint  

  **ctmprod-user**: Control-M username for logging in via Automation API    

  **ctmprod-password**: The password for the Control-M user    

  **ctmprod-agentuser**: The Linux user under which the Control-M agent was installed/provisioned. This value is normall configured by the installation process in the sample rc.agent-user script but since a generic script is being used here, this secret enables the initialization script to determine the agent user dynamically.  

## Video tutorial
Create an AMI with embedded Control-M Agent

 https://youtu.be/nTLdA0U2tgU 

You can find the latest Control-M Automation API documentation, including a programming guide, on the [**project web page**](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Getting+Started+Guide).
