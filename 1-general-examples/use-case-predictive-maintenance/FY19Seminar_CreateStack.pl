$ENV{AWS_ACCESS_KEY_ID } = "your access key";
$ENV{AWS_SECRET_ACCESS_KEY } = "your secret access key";
$ENV{AWS_DEFAULT_REGION } = "us-west-2";

print "User: ".$ENV{USERNAME}."\n";
my $winuser = trim(`echo %USERNAME%`);

my $aws_cf_template = "https://s3-us-west-2.amazonaws.com/623469066856-fy19seminar/FY19Seminar_CF_Template_2018_04_16";

my $EventLog = "C:\\Users\\$winuser\\FY19Seminar_EventLogger.log";
my $szLogHandle = "LOGFILE";
my $szLogMsg;
my $FinalRC = 0;
my $CTMPass = "434178361{oN";

open ( LOGFILE, ">>$EventLog") ||
  die "Cannot open $EventLog";
  
$szLogMsg = ">>>>> Starting FY19Seminar Create Stack";
log_msg($szLogHandle, $szLogMsg);  

$szLogMsg = "      Running as User: ".$winuser." ";
log_msg($szLogHandle, rtrim($szLogMsg));  

#
#   Echo Parms to Logfile and Output
#
for ($idx = 0; $idx < ($#ARGV + 1); $idx += 1) {
   $szLogMsg = "      Parm".$idx.": ".$ARGV[$idx];
   log_msg($szLogHandle, $szLogMsg);
   print "             Parm".$idx.": ".$ARGV[$idx]."\n";
}

$Phone = $ARGV[0];		# Requester Mobile Phone
$OrderID = $ARGV[1];	# Unique ID for this Stack


#
#	Main Process
#

print "Moble: $Phone \n";
	
@CreateUserResp = create_AWS_Stack($Phone, $OrderID);
$CreateUserResultCode = $?;
 	
if ($CreateUserResultCode eq 0) {
	$FinalRC = 0;
}
else {
	$FinalRC = 255;
}
   
print "CreateUser Result Code: $CreateUserResultCode \n";   
    
exit $FinalRC;

#-------------------------------------------------------+
#  create_AWS_Stack function                            |
#-------------------------------------------------------+
sub create_AWS_Stack
{
	
	$Phone = $_[0];
	$CTMOID = $_[1];
	
	$StackName = "FY19Seminar-Stack-".$CTMOID;
	
	print "User submitted info: $Phone $StackName \n";
	
	@Resp = `aws cloudformation create-stack --stack-name $StackName --template-url \"$aws_cf_template\"`;
	$CreateStack = $?;

	if ($CreateStack ne 0) {
 		print "Error in stack creation \n";
		for ($idx = 0; $idx < ($#Resp + 1); $idx += 1) {
			print $Resp[$idx]." \n";
		}
		exit $CreateStack;
	}

	$CreateStatus = 12; 	
	$NotDone = 1;
	while ($NotDone) {
		@Resp = `aws cloudformation describe-stacks --stack-name $StackName`;
		$DescribeStack = $?;
		if ($DescribeStack eq 0) {
			for ($idx = 0; $idx < ($#Resp + 1); $idx += 1) {
				if ((index($Resp[$idx], "\"StackStatus\"")) gt 0) {	
					print $Resp[$idx]." \n";
				
					
					CreateStatus: {
						if (index($Resp[$idx], "CREATE_IN_PROGRESS") > -1) 			{last CreateStatus}
						if (index($Resp[$idx], "CREATE_COMPLETE") > -1) 			{$CreateStatus = 0; $NotDone = 0; last CreateStatus}
						if (index($Resp[$idx], "ROLLBACK_IN_PROGRESS") > -1) 		{$CreateStatus = 12; last CreateStatus}
						if (index($Resp[$idx], "ROLLBACK_COMPLETE") > -1) 			{$CreateStatus = 12; $NotDone = 0; last CreateStatus}
					
						print "Stack Status $Resp[$idx] is unexpected \n";
						exit 4096;
					}
				}	
			}
		}
		else {
			print "Error processing stack creation during describe-stacks \n";
			exit;
		}
		if ($NotDone) {
			sleep 30;
		}
	}

	sleep 10;			# Delay response by some amount of time

	if ($CreateStatus eq 0) {
		@Resp = `aws cloudformation describe-stacks --stack-name $StackName`;
		$DescribeStack = $?;
		if ($DescribeStack eq 0) {
			for ($idx = 0; $idx < ($#Resp + 1); $idx += 1) {
				if ((index($Resp[$idx], "\"OutputKey\": \"ServerInstancePublicIP\"")) gt 0) {	
					print $Resp[$idx + 1]." \n";
#
#					"OutputValue": "52.26.130.187"
#
					@PublicIP = split /\"/, $Resp[$idx + 1];
					print "Public IP Address for Control-M machine is: ".$PublicIP[3]." \n";
					@Resp = `aws sns publish --phone-number $Phone --message \"Your Control-M IP Address is $PublicIP[3] and the password is $CTMPass \"`;
					$ClientIP = $PublicIP[3];
				}	
			}
		}
		else {
			print "Error during describe-stacks to get IP Address \n";
			$CreateStatus = 8;
		}
	}

	$CreateStackResultCode = $CreateStatus;

	
	return $CreateStackResultCode;

}

#-------------------------------------------------------+
#  log_msg function                                     |
#-------------------------------------------------------+

sub log_msg
{
   my ($logfile) = $_[0];
   my ($logmsg) = $_[1];
   my ($sec,$min,$hour,$mday,$mon,$year);

   if ($logfile ne "no_log") {
      ($sec,$min,$hour,$mday,$mon,$year) = localtime(); 
      print LOGFILE ($mon + 1)."\\".$mday."\\".($year + 1900)." ".$hour.":".$min.":".$sec." $logmsg\n";
   }
}

sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}	