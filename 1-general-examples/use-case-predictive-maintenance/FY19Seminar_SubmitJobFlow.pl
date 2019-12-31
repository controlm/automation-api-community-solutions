#
#	Set up a default in case no volunteers
#
$Phone1 = "+country and phone number";
$Phone2 = $Phone1;

if (($#ARGV) > -1) {
		$Phone1 = $ARGV[0];
}
if (($#ARGV) > 0) {
		$Phone2 = $ARGV[1];
}

my $JsonOUT = "C:\\BMC_Stuff\\ViJ_Notify_Parms.json";
open ( JsonOUT, ">$JsonOUT") ||
	die "Cannot open $JsonOUT";
	
$JSONorec = "{ 	\n";
print JsonOUT $JSONorec;
$JSONorec = "  \"variables\": [\n";
print JsonOUT $JSONorec;
$JSONorec = "    {\"phone1\":\"$Phone1\"},\n";
print JsonOUT $JSONorec;
$JSONorec = "    {\"phone2\":\"$Phone2\"} \n";
print JsonOUT $JSONorec;
$JSONorec = "  ]\n";
print JsonOUT $JSONorec;
$JSONorec = "} 	\n";
print JsonOUT $JSONorec;
close (JsonOUT);

@Resp = `ctm deploy \"C:\\BMC_Stuff\\FY19Seminar.json\"`;
print @Resp;

@Resp = `ctm run order controlm IOT_Pipeline -f \"C:\\BMC_Stuff\\ViJ_Notify_Parms.json\"`;
print @Resp;

exit;