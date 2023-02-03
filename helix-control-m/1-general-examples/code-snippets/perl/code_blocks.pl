#!/usr/bin/env perl
use JSON;
use JSON::Parse 'valid_json';
use REST::Client;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );
use Getopt::Long;

## API URL - MODIFY THIS
$ctmapi_url='https://bmcl2-1-4188-aapi.qa.controlm.com/automation-api';

# Script usage text
$usagetext = "$0 [--tokenfile filename]\n";
$helptext  = $usagetext .
  "  --tokenfile:   File containing the API token\n" .
  "  --help:     Print this text\n";

# Function for prompting for API token
sub prompt_for_token {
    require Term::ReadKey;

    Term::ReadKey::ReadMode('noecho');
    print "API Token: ";
    my $token = Term::ReadKey::ReadLine(0);
    Term::ReadKey::ReadMode('restore');
    $token =~ s/\R\z//;
    print "\n";

    return $token;
}

# Parse command line options
GetOptions(
  'tokenfile=s' => \$tokenfile,
  'help'     => \$help
) or die $usagetext;

if($help) { die($helptext); } # if --help show help text and end

# if token file was specified, read token from file, else prompt user
if( $pwfile ) {
  if( -e $pwfile ) {
    open my $file, '<', $pwfile;
    $token = <$file>;
    chomp($token);
    close $file;
  }
  else {
    die("File $pwfile not found!")
  }
}
else {
  $token=prompt_for_token();
}

# initialize REST client
my $client = REST::Client->new();
$client->setHost($ctmapi_url);

# example Get Roles request (make sure the token has config authorizations)
$client->addHeader('Content-Type', 'application/json');
$client->addHeader('x-api-key', $token);
$client->GET('/config/authorization/roles', $reqbody);

# Handle errors
if ($client->responseCode() != 200) {
  if( valid_json($client->responseContent()) ) {
    $json=from_json($client->responseContent());
    print $json->{errors}[0]->{message} . "\n";
  }
  else {
    print $client->responseContent() . "\n";
 }
 exit(1);
}

#  print response
print "Get Roles Response:\n";
print $client->responseContent() . "\n";

