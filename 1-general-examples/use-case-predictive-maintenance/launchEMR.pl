$ENV{AWS_ACCESS_KEY_ID } = "your access key";
$ENV{AWS_SECRET_ACCESS_KEY } = "your secret access key";
$ENV{AWS_DEFAULT_REGION } = "us-west-2";
my ($sec,$min,$hour,$mday,$mon,$year) = localtime(); 
print "Time: ".($mon + 1)."\\".$mday."\\".($year + 1900)." ".$hour.":".$min.":".$sec." \n\n";
$InstanceID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`;
print "Instance: $InstanceID \n";

#
#	Get VPC and Subnet
#
@IDS=`aws ec2 describe-instances --instance-ids $InstanceID --query Reservations[0].Instances[0].[VpcId,SubnetId]`;

$VPCID = $IDS[1];
$VPCID =~ s/\"//g;
$VPCID =~ s/\,//g;
$VPCID = trim($VPCID);

$SubnetID = $IDS[2];
$SubnetID =~ s/\"//g;
$SubnetID = trim($SubnetID);


print "VPC: $VPCID \n";
print "Subnet: $SubnetID \n";

#	
#	Get Securty Group
#
@SGIDS=`aws ec2 describe-security-groups --filter Name=vpc-id,Values=$VPCID Name=tag-key,Values=aws:cloudformation:logical-id Name=tag-value,Values=EMRMasterSecurityGroup --query SecurityGroups[0].[GroupId]`;

$SGID = $SGIDS[1];
$SGID =~ s/\"//g;
$SGID = trim($SGID);
print "SecurityGroup: $SGID \n";

$P1 = "aws emr create-cluster --no-termination-protected --applications Name=Hadoop Name=Spark --tags \"Name=FY19Seminar Demo EMR Master\" --ec2-attributes \"{\\\"KeyName\\\":\\\"FY19SeminarKey\\\",\\\"InstanceProfile\\\":\\\"EMR_EC2_DefaultRole\\\",\\\"EmrManagedMasterSecurityGroup\\\":\\\"$SGID\\\",\\\"EmrManagedSlaveSecurityGroup\\\":\\\"$SGID\\\",\\\"SubnetId\\\":\\\"$SubnetID\\\"}\" --release-label emr-5.13.0 --log-uri \"s3n://aws-logs-623469066856-us-west-2/elasticmapreduce/\" ";

$P2 = "--instance-groups  \"[{\\\"InstanceCount\\\":1,\\\"EbsConfiguration\\\":{\\\"EbsBlockDeviceConfigs\\\":[{\\\"VolumeSpecification\\\":{\\\"SizeInGB\\\":100,\\\"VolumeType\\\":\\\"gp2\\\"},\\\"VolumesPerInstance\\\":1}]},\\\"InstanceGroupType\\\":\\\"MASTER\\\",\\\"InstanceType\\\":\\\"m4.large\\\",\\\"Name\\\":\\\"Master-1\\\"}]\" ";

$P3 = "--auto-scaling-role EMR_AutoScaling_DefaultRole --ebs-root-volume-size 40 --service-role EMR_DefaultRole --enable-debugging --name \"FY19SeminarDemo\" --scale-down-behavior TERMINATE_AT_TASK_COMPLETION --region us-west-2 --bootstrap-actions Path=\"s3://623469066856-fy19seminar/EMRBootStrap.sh\"";

$CMD = "$P1$P2$P3";
print "Command: ".$CMD." \n";

@RESPMsg=`$CMD`;

$CInfo = $RESPMsg[1];
$CInfo =~ s/\"//g;
@ClusterID = split /:/, $CInfo;
$CID = trim($ClusterID[1]);
print "Cluster ID: $CID \n";
my ($sec,$min,$hour,$mday,$mon,$year) = localtime(); 
print "Cluster created at: ".($mon + 1)."\\".$mday."\\".($year + 1900)." ".$hour.":".$min.":".$sec." \n";

#
#	Wait for cluster to enter running state
#
@MSG = `aws emr wait cluster-running --cluster-id $CID`;
my ($sec,$min,$hour,$mday,$mon,$year) = localtime(); 
print "Cluster running at: ".($mon + 1)."\\".$mday."\\".($year + 1900)." ".$hour.":".$min.":".$sec." \n";

exit;

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}	