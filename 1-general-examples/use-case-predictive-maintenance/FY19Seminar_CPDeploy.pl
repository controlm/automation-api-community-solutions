
my $JsonIN = "C:\\BMC_Stuff\\FY19Seminar_CP.json";
my $JsonOUT = "C:\\BMC_Stuff\\EMR_CP.json";

@JSON=`ctm config server:agents::get controlm`;

for ($idx = 0; $idx < ($#JSON + 1); $idx += 1) {
#	print "Parm".$idx.": ".$JSON[$idx]."\n";
	$Line = $JSON[$idx];
	$Line =~ s/\"//g;
	$Line = trim($Line);
	@Rec = split /:/, $Line;
	if ($Rec[0] eq "nodeid" and lc(substr($Rec[1],1,3)) eq "ip-") {
		$Agent = trim($Rec[1]);
		$Agent =~ s/\,//g;
		print "Appears to be the EMR agent: $Agent \n";
		$Line = $JSON[$idx + 1];
		$Line =~ s/\"//g;
		$Line = trim($Line);
		@Rec = split /:/, $Line;
		if ( lc(trim($Rec[0])) eq "status" and lc(trim($Rec[1])) eq "available") {
			print "And it is available \n";
			open ( JsonIN, "<$JsonIN") ||
				die "Cannot open $JsonIN";
  
			open ( JsonOUT, ">$JsonOUT") ||
				die "Cannot open $JsonOUT";

			while ( <JsonIN> )
			{
	
				$JSONorec = $_;
				$JSONorec =~ s/\[ip-aaa-a-aa-aaa\]/$Agent/g;
				print JsonOUT $JSONorec;

			}

			close (JsonIN, JsonOUT);
			@Resp = `ctm deploy $JsonOUT`;
			print @Resp;
		}
    }
   
}

my $KnownHostsFile = "C:\\Program Files\\BMC Software\\Control-M Agent\\Default\\CM\\AFT\\data\\known_hosts";
open (KHosts, ">$KnownHostsFile") ||
	die "Cannot open $KnownHostsFile";;
# print KHosts " ";
close (KHosts);

exit;

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}