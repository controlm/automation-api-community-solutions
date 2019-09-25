resource "tls_private_key" "new_ssh_keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "ctm-ami-key"
  public_key = "${tls_private_key.new_ssh_keypair.public_key_openssh}"
}

resource "random_password" "dbofirst" {
  length = 1
  special = false
  number = false
}

resource "random_password" "dbafirst" {
  length = 1
  special = false
  number = false
}

resource "random_password" "dbopass" {
  length = 15
  special = false
}

resource "random_password" "dbapass" {
  length = 15
  special = false
}

locals {
  dbopass = "${random_password.dbofirst.result}${random_password.dbopass.result}"
  dbapass = "${random_password.dbafirst.result}${random_password.dbapass.result}"
}

resource "aws_cloudformation_stack" "example" {
  name                    = "ctm-terraform-aws-ami"

  parameters = {
    MultiAZDatabase = false,
    CIDRForSSH = "0.0.0.0/0",
    CTMDBOPassword = "${local.dbopass}",
    EMDBOPassword = "${local.dbopass}",
    DBAdminPassword = "${local.dbapass}",
    KeyName = "${aws_key_pair.generated_key.key_name}"
    }

  template_body = <<TEMPLATE
{
  "AWSTemplateFormatVersion" : "2010-09-09",

  "Description" : "AWS CloudFormation Template for Control-M. This template creates an Amazon Relational Database Service database instance. You will be billed for the AWS resources used if you create a stack from this template.",
  "Metadata" : {
    "AWS::CloudFormation::Interface" : {
      "ParameterGroups" : [{
		"Label" : {"default": "PostgreSQL RDS Database Properties"},
        "Parameters" : ["DBVersion", "DBClass", "MultiAZDatabase", "DBStorageType", "DBAllocatedStorage", "DBAdminPassword"]
      },{
		"Label" : {"default": "EC2 Instance Properties"},
        "Parameters" : ["Ec2InstanceType", "KeyName", "IpType", "CIDRForSSH", "CIDRForCTM"]
      },{
        "Label" : {"default": "Control-M Properties"},
        "Parameters" : ["EMDBOUsername", "EMDBOPassword", "CTMDBOUsername", "CTMDBOPassword"]
	  }],
      "ParameterLabels" : {
        "DBClass": {"default": "DB Instance Class"},
		"DBVersion": {"default": "DB Engine Version"},
        "MultiAZDatabase": {"default": "Multi-AZ Deployment"},
		"DBStorageType": {"default": "Storage Type"},
		"DBAllocatedStorage": {"default": "Allocated Storage"},
		"DBAdminPassword": {"default": "Master Password"},
		"Ec2InstanceType": {"default": "Instance Type"},
		"KeyName": {"default": "Key Pair Name"},
		"IpType": {"default": "Elastic IP"},
		"EMDBOUsername": {"default": "Username"},
		"EMDBOPassword": {"default": "Password"},
		"CTMDBOUsername": {"default": "CTM DBO Username"},
		"CTMDBOPassword": {"default": "CTM DBO Password"},
		"CIDRForSSH": {"default": "SSH Access CIDR"},
		"CIDRForCTM": {"default": "Control-M Access CIDR"}
      }
    }
  },
  "Parameters" : {
    "DBStorageType" : {
      "Default" : "standard",
      "Description" : "Database storage type. Note: Provisioning less than 100 GB of General Purpose (SSD) storage for high throughput workloads could result in higher latencies upon exhaustion of the initial General Purpose (SSD) IO credit balance",
      "Type" : "String",
      "AllowedValues" : [ "standard", "gp2" ],
      "ConstraintDescription" : "must select a valid database storage type."
    },
    "MultiAZDatabase": {
      "Default": "true",
      "Description": "Select Yes to have Amazon RDS maintain a synchronous standby replica in a different Availability Zone than the DB instance. Amazon RDS will automatically fail over to the standby in the case of a planned or unplanned outage of the primary.",
      "Type": "String",
      "AllowedValues": [
        "true",
        "false"
      ],
      "ConstraintDescription": "must be either true or false."
    },
	"KeyName": {
      "Description": "Name of an existing EC2 Key Pair to enable SSH access to the instance",
      "Type": "AWS::EC2::KeyPair::KeyName",
      "ConstraintDescription": "must be the name of an existing EC2 KeyPair."
    },
    "CIDRForSSH": {
         "Description": "Allow inbound SSH network traffic from this address range (0.0.0.0/0 will allow all)",
         "Type": "String",
         "MinLength": "9",
         "MaxLength": "18",
         "AllowedPattern": "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
         "ConstraintDescription": "Must be a valid CIDR range of the form x.x.x.x/x."
    },
	"CIDRForCTM": {
         "Description": "Allow inbound network traffic from this address range (0.0.0.0/0 will allow all)",
         "Type": "String",
         "MinLength": "9",
         "MaxLength": "18",
         "Default": "0.0.0.0/0",
         "AllowedPattern": "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
         "ConstraintDescription": "Must be a valid CIDR range of the form x.x.x.x/x."
    },
	"CTMDBOUsername": {
      "Default": "ctmuser",
      "NoEcho": "false",
      "Description" : "Control-M Server database owner username. Must begin with a letter (a-z) followed by 29 characters or underscores.",
      "Type": "String",
      "MinLength": "1",
      "MaxLength": "30",
      "AllowedPattern" : "[a-z][a-z_0-9]*",
      "ConstraintDescription" : "must begin with a letter (a-z) followed by up to 29 characters or underscores."
    },
	"CTMDBOPassword": {

      "NoEcho": "true",
      "Description" : "Control-M Server database owner password. Must begin with a letter (A-Z, a-z) followed by 29 alphanumeric characters or underscores.",
      "Type": "String",
      "MinLength": "5",
      "MaxLength": "30",
      "AllowedPattern" : "[a-zA-Z][a-zA-Z_0-9]*",
      "ConstraintDescription" : "must begin with a letter (A-Z,a-z) followed by 5 to 29 characters or underscores."
    },
	"EMDBOUsername": {
      "Default": "emuser",
      "NoEcho": "false",
      "Description" : "Control-M Enterprise login username, this  is also the database owner username. Must begin with a letter (a-z) followed by 29 characters or underscores.",
      "Type": "String",
      "MinLength": "1",
      "MaxLength": "30",
      "AllowedPattern" : "[a-z][a-z_0-9]*",
      "ConstraintDescription" : "must begin with a letter (a-z) followed by up to 29 characters or underscores."
    },
	"EMDBOPassword": {

      "NoEcho": "true",
      "Description" : "Control-M Enterprise login password , this  is also the database owner password.  Must begin with a letter (A-Z, a-z) followed by 29 alphanumeric characters or underscores. ",
      "Type": "String",
      "MinLength": "5",
      "MaxLength": "30",
      "AllowedPattern" : "[a-zA-Z][a-zA-Z_0-9]*",
      "ConstraintDescription" : "must begin with a letter (A-Z,a-z) followed by 5 to 29 characters or underscores."
    },
    "DBAdminPassword": {

      "NoEcho": "true",
      "Description" : "Specify a string that defines the password for the master user. Master Password must be at least eight characters long, as in \"mypassword\".",
      "Type": "String",
      "MinLength": "8",
      "MaxLength": "41",
      "AllowedPattern" : "[a-zA-Z0-9]*",
      "ConstraintDescription" : "must contain only alphanumeric characters."
    },

    "DBClass" : {
      "Default" : "db.m3.xlarge",
      "Description" : "Select the DB instance class that allocates the computational, network, and memory capacity required by planned workload of this DB instance. More info at AWS docs.",
      "Type" : "String",
      "AllowedValues" : [ "db.m4.large","db.m4.xlarge","db.m4.2xlarge","db.m4.4xlarge","db.m4.10xarge","db.m3.large","db.m3.xlarge","db.m3.2xlarge","db.r3.large","db.r3.xlarge","db.r3.2xlarge","db.r3.4xlarge","db.r3.8xlarge" ],
      "ConstraintDescription" : "must select a valid database instance type."
    },

    "DBAllocatedStorage" : {
      "Default": "40",
      "Description" : "More info at AWS docs.",
      "Type": "Number",
      "MinValue": "40",
      "MaxValue": "1024",
      "ConstraintDescription" : "must be between 40 and 1024Gb."
    },
	"DBVersion" : {
      "Default": "9.6.10",
      "Description" : "Version number of the database engine to be used for this instance.",
      "Type": "String",
      "AllowedValues" : [ "10.5","10.4","10.3","10.1","9.6.10","9.6.9","9.6.8","9.6.6","9.6.5","9.6.3","9.6.2","9.6.1","9.5.14","9.5.13","9.5.12","9.5.10","9.5.9","9.5.7","9.5.6","9.5.4","9.5.2","9.4.19","9.4.18","9.4.17","9.4.15","9.4.14","9.4.12","9.4.11","9.4.9","9.4.7","9.3.24","9.3.23","9.3.22","9.3.20","9.3.19","9.3.17","9.3.16","9.3.14","9.3.12" ],
      "ConstraintDescription" : "must select a valid database version"
    },
	"Ec2InstanceType" : {
      "Default" : "m3.xlarge",
      "Description" : "Amazon EC2 provides a wide selection of instance types optimized to fit different use cases. Instances are virtual servers that can run applications. They have varying combinations of CPU, memory, storage, and networking capacity.",
      "Type" : "String",
      "AllowedValues" : [ "m3.large","m3.xlarge","m3.2xlarge","m4.large","m4.xlarge","m4.2xlarge","m4.4xlarge","m4.10xlarge","c3.large","c3.xlarge","c3.2xlarge","c3.4xlarge","c3.8xlarge","c4.large","c4.xlarge","c4.2xlarge","c4.4xlarge","c4.8xlarge","g2.2xlarge","g2.8xlarge","cg1.4xlarge","cr1.8xlarge","r3.large","r3.xlarge","r3.2xlarge","r3.4xlarge","r3.8xlarge","i2.xlarge","i2.2xlarge","i2.4xlarge","i2.8xlarge","hi1.4xlarge","hs1.8xlarge","d2.xlarge","d2.2xlarge","d2.4xlarge","d2.8xlarge" ],
      "ConstraintDescription" : "must select a valid EC2 instance type."
    },
	"IpType" : {
      "Description" : "Choose whether to use static IP address",
      "Default" : "No",
      "Type" : "String",
      "AllowedValues" : ["Yes", "No"],
      "ConstraintDescription" : "must specify Yes or No."
    }
  },
  "Conditions" : {
    "CreateEIP" : {"Fn::Equals" : [{"Ref" : "IpType"}, "Yes"]},
	"Is-EC2-VPC": {
      "Fn::Or": [
        {
          "Fn::Equals": [
            {
              "Ref": "AWS::Region"
            },
            "eu-central-1"
          ]
        },
        {
          "Fn::Equals": [
            {
              "Ref": "AWS::Region"
            },
            "cn-north-1"
          ]
        },
        {
          "Fn::Equals": [
            {
              "Ref": "AWS::Region"
            },
            "ap-northeast-2"
          ]
        }
      ]
    },
    "Is-EC2-Classic": {
      "Fn::Not": [
        {
          "Condition": "Is-EC2-VPC"
        }
      ]
    }
  },
  "Mappings" : {
		"RegionMap" : {
			"us-east-1"           : {"AMI" : "ami-01d880bc68dc2aaf1"},
			"us-west-1"           : {"AMI" : "ami-00b7257f131703d36"},
			"us-west-2"           : {"AMI" : "ami-02c847b0469e06b02"},
			"eu-central-1"        : {"AMI" : "ami-07cb0884d393017c9"},
			"eu-west-1"           : {"AMI" : "ami-0dc29335084461f53"},
			"ap-southeast-1"      : {"AMI" : "ami-07888afdf7402b965"},
			"ap-southeast-2"      : {"AMI" : "ami-07a22f811d29fd870"},
			"ap-south-1"          : {"AMI" : "ami-0ae75f0b508874fd4"},
			"ap-northeast-1"      : {"AMI" : "ami-06e9c5c5d8d8f9b35"},
			"ap-northeast-2"      : {"AMI" : "ami-0fb50e83136714ac6"},
			"sa-east-1"           : {"AMI" : "ami-03b58402c3c60b61d"}
		}
  },
  "Resources" : {

	"ControlM" : {
        "Type" : "AWS::EC2::Instance",
		"Metadata" : {
            "AWS::CloudFormation::Init" : {
                "config" : {
				    "files" : {
						"/tmp/PostLaunchParams.txt" : {
							"content" : { "Fn::Join" : ["", [

							  "EMDBOUsername ", { "Ref" : "EMDBOUsername" }, "\n",
							  "EMDBOPassword  ", { "Ref" : "EMDBOPassword" }, "\n",
							  "DBAdminUsername  postgres\n",
							  "DBAdminPassword  ", { "Ref" : "DBAdminPassword" }, "\n",
							  "DbHostName  ", { "Fn::GetAtt": [ "MyDB", "Endpoint.Address" ] }, "\n",
							  "DbPort  ", { "Fn::GetAtt": [ "MyDB", "Endpoint.Port" ] }, "\n",
							  "DbVersion  ", { "Ref" : "DBVersion" }, "\n",
							  "CTMDBOUsername   ", { "Ref" : "CTMDBOUsername" }, "\n",
							  "CTMDBOPassword  ", { "Ref" : "CTMDBOPassword" }, "\n"

							  ]]},
							"mode"  : "000644",
							"owner" : "controlm",
							"group" : "controlm"
						}
					},
					"commands" : {
						"RunPost" : {
							"command" : "su - controlm -c \"cd PostLaunch ; ./post_launch.csh /tmp/PostLaunchParams.txt >& /tmp/PostLaunch.log\"",
							"cwd" : "~"
						}
					}
				}
			}
		},
        "Properties" : {
            "ImageId" : { "Fn::FindInMap" : [ "RegionMap", { "Ref" : "AWS::Region" }, "AMI" ]},
			"InstanceType" : { "Ref" : "Ec2InstanceType" },
			"KeyName": {"Ref": "KeyName"},
			"SecurityGroups": [{ "Ref": "ControlmSecurityGroup" }],
			"UserData"       : { "Fn::Base64" : { "Fn::Join" : ["", [
				"#!/bin/bash -v\n",

				"/usr/bin/cfn-init -s ", { "Ref" : "AWS::StackId" }, " -r ControlM ",
				"    --region ", { "Ref" : "AWS::Region" },
				"\n",
                "# Signal the status from cfn-init\n",
				"/usr/bin/cfn-signal -e $? --stack ", { "Ref" : "AWS::StackId" }, " --resource ControlM ",
				"    --region ", { "Ref" : "AWS::Region" },
				"\n"


			]]}}
        },
			"DependsOn" : "MyDB"
        },
    "MyDB" : {
        "Type" : "AWS::RDS::DBInstance",
        "Properties" : {
			"VPCSecurityGroups": {
			  "Fn::If": [
				"Is-EC2-VPC",
				[
				  {
					"Fn::GetAtt": [
					  "DBEC2SecurityGroup",
					  "GroupId"
					]
				  }
				],
				{
				  "Ref": "AWS::NoValue"
				}
			  ]
			},
			"DBSecurityGroups": {
			  "Fn::If": [
				"Is-EC2-Classic",
				[
				  {
					"Ref": "DBSecurityGroup"
				  }
				],
				{
				  "Ref": "AWS::NoValue"
				}
			  ]
			},
			"AllocatedStorage" : { "Ref" : "DBAllocatedStorage" },
			"StorageType" : { "Ref" : "DBStorageType" },
			"DBInstanceClass" : { "Ref" : "DBClass" },
			"MultiAZ": { "Ref": "MultiAZDatabase" },
			"Engine" : "postgres",
			"EngineVersion" : { "Ref" : "DBVersion" } ,
			"MasterUsername" : "postgres",
			"MasterUserPassword" : { "Ref" : "DBAdminPassword" }

      }
    },
	"MyEIP" : {
	 "Type" : "AWS::EC2::EIP",
	 "Condition" : "CreateEIP",
	 "Properties" : {
		 "InstanceId" : { "Ref" : "ControlM" }
	 }
    },
	"ControlmSecurityGroup" : {
		"Type" : "AWS::EC2::SecurityGroup",
		"Properties" : {
		  "GroupDescription" : "allow connections from specified CIDR ranges",
		    "SecurityGroupIngress" : [
				 {
					 "IpProtocol" : "tcp",
					 "FromPort" : "13075",
					 "ToPort" : "13100",
					 "CidrIp" : { "Ref": "CIDRForCTM" }
				 },{
					 "IpProtocol" : "tcp",
					 "FromPort" : "22",
					 "ToPort" : "22",
					 "CidrIp" : { "Ref": "CIDRForSSH" }
				 },{
					 "IpProtocol" : "tcp",
					 "FromPort" : "18080",
					 "ToPort" : "18080",
					 "CidrIp" : { "Ref": "CIDRForCTM" }
				},{
					 "IpProtocol" : "tcp",
					 "FromPort" : "8446",
					 "ToPort" : "8446",
					 "CidrIp" : { "Ref": "CIDRForCTM" }
				 },{
					 "IpProtocol" : "tcp",
					 "FromPort" : "7",
					 "ToPort" : "7",
					 "CidrIp" : { "Ref": "CIDRForCTM" }
				 },{
					 "IpProtocol" : "tcp",
					 "FromPort" : "7005",
					 "ToPort" : "7005",
					 "CidrIp" : { "Ref": "CIDRForCTM" }
				 }
            ]
        }
    },
	"DBEC2SecurityGroup" : {
		"Type" : "AWS::EC2::SecurityGroup",
		"Condition": "Is-EC2-VPC",
		"Properties" : {
		  "GroupDescription" : "Open Database for access via port 5432",
		    "SecurityGroupIngress" : [
				 {
					 "IpProtocol" : "tcp",
					 "FromPort" : "5432",
					 "ToPort" : "5432",
					 "CidrIp" : { "Ref": "CIDRForCTM" }
				 }
            ]
        }
    },
	"DBSecurityGroup": {
      "Type": "AWS::RDS::DBSecurityGroup",
      "Condition": "Is-EC2-Classic",
      "Properties": {
        "DBSecurityGroupIngress": {
          "CIDRIP": { "Ref": "CIDRForCTM" }
        },
        "GroupDescription": "database access"
      }
    }
  },
  "Outputs": {
    "Ec2Instance": {
      "Value": "ControlM"
    },
    "WebsiteURL": {
      "Description": "Starting page URL to get links to download the clients or API KIT , links to help video’s and  more. ",
      "Value": {
        "Fn::Join": [
          "",
          [
            "http://",
            {
              "Fn::GetAtt": [
                "ControlM",
                "PublicDnsName"
              ]
            },
            ":18080"
          ]
        ]
      }
    },
    "HttpsURL": {
      "Description": "HTTPS URL for use with Automation API",
      "Value": {
        "Fn::Join": [
          "",
          [
            "https://",
            {
              "Fn::GetAtt": [
                "ControlM",
                "PublicDnsName"
              ]
            },
            ":8446"
          ]
        ]
      }
    }
  }
}

TEMPLATE
}

output "dbo_password" {
  value       = local.dbopass
  description = "The password for logging in to the Control-M/Enterprise Manager admin accounnt and Control-M DBO accounts"
  sensitive   = true
}

output "dba_password" {
  value       = local.dbapass
  description = "The password for logging in to the database admin account."
  sensitive   = true
}

output "ssh_private_key" {
  value       = tls_private_key.new_ssh_keypair.private_key_pem
  description = "The SSH private key used to login to the EC2 instance via SSH"
  sensitive   = true
}

output "ctmcli_command" {
  value       = "ctm session login -e ${aws_cloudformation_stack.example.name}"
  description = "Command to test Automation API connection"
}

resource "local_file" "private_key" {
    sensitive_content      = "${tls_private_key.new_ssh_keypair.private_key_pem}"
    filename = "${path.module}/id_rsa"
}

resource "null_resource" "ctm_cli_environment" {
    triggers = {
      uuid = "${aws_cloudformation_stack.example.id}"
    }

    provisioner "local-exec" {
      command = <<EOT
for n in $(seq 1 30); do
curl -s -f -k ${aws_cloudformation_stack.example.outputs["HttpsURL"]} 1>/dev/null 2>&1;
if [ $? -eq 0 ]; then
break
else
sleep 10
fi
done
which nodejs > /dev/null 2>&1;
RC1=$?
which npm > /dev/null 2>&1;
RC2=$?
if [ $RC1 -ne 0 ] || [ $RC2 -ne 0 ]; then
	echo "Must install nodejs and npm then run:"
	cat << EOF
	curl -k -o ctm-cli.tgz ${aws_cloudformation_stack.example.outputs["HttpsURL"]}/automation-api/ctm-cli.tgz
	npm install -g ctm-cli.tgz
	ctm env add ${aws_cloudformation_stack.example.name} ${aws_cloudformation_stack.example.outputs["HttpsURL"]}/automation-api emuser ${local.dbopass}
EOF
	exit 1
else
	which ctm > /dev/null 2>&1;
	RC=$?
	if [ $RC -ne 0 ]; then
		echo "downloading and installing ctm cli"
		curl -k -o ctm-cli.tgz ${aws_cloudformation_stack.example.outputs["HttpsURL"]}/automation-api/ctm-cli.tgz
		if [ $? -ne 0 ]; then
			echo "Failed to download ctm-cli, Control-M Cloud Formation stack may not be fully started. Please try manually later"
			exit 2
		fi
		npm install -g ctm-cli.tgz
		if [ $? -ne 0 ]; then
			echo "Failed to install ctm-cli, likely due to permissions. Please try manully with sudo or change your npm prefix"
			exit 2
		fi
	fi
echo "Adding ctm environment"
ctm env add ${aws_cloudformation_stack.example.name} ${aws_cloudformation_stack.example.outputs["HttpsURL"]}/automation-api emuser ${local.dbopass}
echo "To use the new ctm environment run: ctm env set ${aws_cloudformation_stack.example.name}"
fi
EOT
      on_failure = "continue"
    }

    provisioner "local-exec" {
      when = "destroy"
      on_failure = "continue"
      command = "ctm env delete ${aws_cloudformation_stack.example.name}"
    }
}
