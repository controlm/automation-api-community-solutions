# Provision a Control-M Environment in AWS using Terraform
### Scenario
As part of an ongoing effort to reduce the resources necessary to maintain and audit infrastructure, a system admin has been asked to provision a Control-M environment in AWS using Terraform.  

### Prerequisites
 * Terraform cli 0.12 or higher
 * Amazon AWS account

\* This example is not intended as a detailed walk through on using Terraform. For more information on getting started with Terraform, please see the official Terraform documentation at [https://www.terraform.io/docs/index.html](https://www.terraform.io/docs/index.html)

### Table of Contents
1. [Setup provider.tf](#setup-providertf)
2. [Review resources.tf](#review-resourcestf)
3. [Run terraform init](#run-terraform-init)
4. [Plan and Apply](#plan-and-apply)

### Setup provider.tf

Create a file name `provider.tf` and in this file, we will tell terraform how to access the AWS credentials need to authenticate to AWS when provisioning infrastructure.

The Terraform documentation on the AWS Provider has a section on [Authentication](https://www.terraform.io/docs/providers/aws/index.html#authentication) that details the different options available. In this example, we've chosen to use the "Shared credentials file" option as it doesn't require hard coding any credentials in the tf files that will be committed to version control repos, or adding the credentials to environment variables.

### Review resources.tf

Create a file named `resources.tf` and in this file, each resource that terraform will provision and manage will be defined.

Below is a table of the main resources from the [resources.tf](./resources.tf) file and it's purpose:

| Resource                                                | Purpose                                                                                                                                                            |  
|---------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|  
| resource.tls_private_key.new_ssh_keypair                | Creates a new SSH key pair to be used to authenticate if ever logging into the provisioned Control-M instance via SSH                                              |  
| resource.aws_key_pair.generated_key                     | Provides AWS the public key of resource.tls_private_key.new_ssh_keypair                                                                                            |  
| resource.random_password.dbofirst                       | Generates a random letter (a-zA-Z) to be the first character of the DBO password                                                                                   |  
| resource.random_password.dbafirst                       | Generates a random letter (a-zA-Z) to be the first character of the DBA password                                                                                   |  
| resource.random_password.dbopass                        | Generates a random alphanumberic (a-zA-Z0-9) string to be the remainder of the DBO password                                                                        |  
| resource.random_password.dbapass                        | Generates a random alphanumberic (a-zA-Z0-9) string to be the remainder of the DBA password                                                                        |  
| locals.dbopass                                          | Combines resource.random_password.dbofirst and resource.random_password.dbopass to meed to password requirements set in the Control-M AWS Cloud Formation template |  
| locals.dbapass                                          | Combines resource.random_password.dbafirst and resource.random_password.dbapass to meed to password requirements set in the Control-M AWS Cloud Formation template |  
| resource.aws_cloudformation_stack.example               | Instructs terraform to use an AWS CloudFormation stack to provision resources in AWS                                                                               |  
| resource.aws_cloudformation_stack.example.parameters    | Sets the inputs to the Cloud Formation stack                                                                                                                       |  
| resource.aws_cloudformation_stack.example.template_body | The JSON format Cloud Formation stack template to be used                                                                                                          |  
| output.dbo_password                                     | Instructs terraform to store the value in the terraform state file so that it can be retrieved later but not output to the shell due to sensitive = true           |  
| output.dba_password                                     | Instructs terraform to store the value in the terraform state file so that it can be retrieved later but not output to the shell due to sensitive = true           |  
| output.ssh_private_key                                  | Sets the ssh private key as a sensitive value that should not be displayed in the shell output                                                                     |  
| output.ctmcli_command                                   | Outputs the command to run to use ctm cli with the new Control-M instance                                                                                          |  
| resource.local_file.private_key                         | Instructs terraform to store the ssh private key in a local file (id_rsa) on the machine where terraform is run                                                    |  
| resource.null_resource.ctm_cli_environment              | When resource.aws_cloudformation_stack.example is provisioned, instructs terraform to run the in line script to install/setup ctm cli.                             |  

### Run terraform init

With all prerequisites and .tf files in place, it is time to run `terraform init`. This command lets terraform get everything inplace to mange the .tf files in the current directory. You can read more about this command in the terraform documentation [here](https://www.terraform.io/docs/commands/init.html)

### Plan and Apply

After successfully running `terraform init`, we can run `terraform plan` to see what resources will be created (or modified if `terraform apply` has previously been run)

By running `terraform apply` the resources will be created with a running status displayed on the terminal output.

### Connecting to the new Control-M instance

If nodejs and npm are installed on the system where terraform is being run the local-exec provisioner of resource.null_resource.ctm_cli_environment will attempt to download and set up the ctm cli (Command Line Interface) for Contol-M's Automation API. If npm or nodejs are not installed, or the ec2 instance does not start in a timely manner, instructions for downloading and configuring ctm cli are printed to the screen.

For more information on Automation API see the online documentation [here](https://docs.bmc.com/docs/ctm/control-m-automation-api-getting-started-guide-634966510.html)

If there is ever a need to logon to the ec2 instance directly, that can be done using the private key stored locally with resource.local_file.private_key. To use it to authenticate via ssh:

```shell
chmod 600 ./id_rsa
ssh -i id_rsa ec2-user@[ec2-PublicDnsName]
```

### Cleanup

To undo the changes (ie. remove the resources managed by terraform) simply run the command `terraform destroy`. For details on the terraform destroy command see the Terraform documentation [here](https://www.terraform.io/docs/commands/destroy.html).
