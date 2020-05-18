$ENV{AWS_ACCESS_KEY_ID } = "your access key";
$ENV{AWS_SECRET_ACCESS_KEY } = "your secret access key";
$ENV{AWS_DEFAULT_REGION } = "us-west-2";

$Phone1 = "+14167225672";
$Phone2 = $Phone1;

if (($#ARGV) > -1) {
		$Phone1 = $ARGV[0];
}
if (($#ARGV) > 0) {
		$Phone2 = $ARGV[1];
}

$Hdr = "|lifetime|broken|     pressureInd|     moistureInd|  temperatureInd| team| provider|";
my $VijIN = "C:\\BMC_Stuff\\ViJ.log";
my $VijOUT = "C:\\BMC_Stuff\\ViJData.txt";

open ( VijIN, "<$VijIN") || die "Cannot open $VijIN";
open ( VijOUT, ">$VijOUT") || die "Cannot open $VijOUT";
$CopyData = 0;

while ( $Vijirec = <VijIN> ) {

	if (index($Vijirec,"$Hdr") != -1) { 
		$CopyData = 1;
		$Vijirec = <VijIN>;
		$Vijirec = <VijIN>;
		$Phone = $Phone1;
	}
	if ($CopyData > 0 and $CopyData < 3) {
		$CopyData = $CopyData + 1;
		chomp($Vijirec);
		@Rec = split /\|/, $Vijirec;
		$Pressure = $Rec[3];
		$Moisture = $Rec[4];
		$Temperature = $Rec[5];
		
		@Resp = `aws sns publish --phone-number $Phone --message "BMC Vehicle in Jeopardy Program: Please visit your service center. Your vehicle is indicating Pressure: $Pressure, Moisture: $Moisture, Temperature: $Temperature"`;
		$Phone = $Phone2;
		$Vijorec = $Vijirec;
		print VijOUT $Vijorec;
	}
}

close (VijIN, VijOUT);

exit;



sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}


