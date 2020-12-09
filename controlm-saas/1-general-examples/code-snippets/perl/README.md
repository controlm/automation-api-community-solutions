# Perl standard code blocks

## Prerequisites

The Perl modules JSON, JSON::Parse, REST::Client and Term::ReadKey have been used in this code.
You can install them using the following commands: 

```
perl -MCPAN -e shell
install JSON
install JSON::Parse
install REST::Client
install Term::ReadKey
```

Please refer to [CPAN documentation](https://www.cpan.org/modules/INSTALL.html) for further help with installing Perl modules.

## Script

The [code_blocks.pl](./code_blocks.pl) script is a self-contained script that demonstrates
how to read command-line arguments, connect to the Control-M API, perform an example
request, and handle errors.

The REST::Client module is used to simplify sending requests to the API.
First initialize the client with the following code:
```
$ctmapi_url='https://YOURTENANT-aapi.us1.controlm.com/automation-api';
my $client = REST::Client->new();
$client->setHost($ctmapi_url);
```

Next, a request can be sent as follows (this example retrieves the authorization roles from the tenant):
```
# example Get Roles request (make sure the token has config authorizations)
$client->addHeader('Content-Type', 'application/json');
$client->addHeader('x-api-key', $token);
$client->GET('/config/authorization/roles', $reqbody);
```
