# Apigee Outbound Authentication

This example demonstrates how to cache Control-M API session tokens and use them 
for outbound calls from an Apigee API proxy to the backend service.

Quickly jump to:
*  [Setup](#setup)
*  [Configuration](#configuration)
*  [Test a request](#test-a-request)
*  [How it works](#how-it-works)

## Requirement

The organisation is using Apigee Edge API gateway as a central hub through which 
APIs in the organisation are available. Access through the the API Gateway is
managed using API Key authentication and the Gateway logs usage for analytics 
and enforces individual access controls.

The Control-M Automation API has to be made available through the API Gateway. 
Developers should only need to present the Apigee API key for authentication, 
the API Gateway is responsible for logging into and keeping a session token for
the Control-M backend.

## Prerequisites

* Control-M/Enterprise Manager 9.0.19.200 or higher*
* Control-M Automation API 9.0.18 or higher

\* An issue present in Control-M/EM 9.0.19 and 9.0.19.100 prevents 
this setup from working. Follow BMC article 000171545 to resolve this issue.


## Setup

This walkthrough does not cover setting up an Apigee account. We recommend the 
[Apigee Get Started Documentation](https://docs.apigee.com/api-platform/get-started/get-started).

The apigeetool utility is used to import the example API Proxy definition into
your Apigee environment.
For more inforamtion on how to install this, see 
[apigeetool installation](https://www.npmjs.com/package/apigeetool#installation).

This example does not walk through the basic steps of setting up an API Proxy 
for Control-M. Please refer to example [Add AAPI service to Apigee Gateway](https://github.com/controlm/automation-api-community-solutions/tree/master/7-api-gateway-integrations/add-aapi-service-to-apigee-gateway).


## Configuration

1. Copy the `apiproxy` directory from this example to a location on the machine
   where you have the apigeetool installed.

2. Edit the following two files which contain the login credentials to your 
Control-M Automation API backend and endpoint url:
```
apiproxy/resources/jsc/api-config.js
apiproxy/targets/default.xml
```

3. From the parent directory where you copied the `apiproxy` directory, run the
   following command:
```
apigeetool deployproxy -u "me@example.com" -o "myorg" -n ctm-outbound-auth -e test
```

Your username is the e-mail address with which you login to Apigee. The 
organisation will be listed there as well. The environment (-e) option specifies
in which environment to deploy the proxy. 
For more information about apigeetool options go 
[here](https://www.npmjs.com/package/apigeetool#deployproxy).

This command deploys the `ctm-outbound-auth` API Proxy to your Apigee 
environment. If a proxy with the same name already exists, a new revision will 
be added to that proxy.

3. Create the cache

The example proxy uses a cache named `ctmtoken` to store the Control-M
Automation API session token. Use the apigeetool to create it:
```
apigeetool createcache "me@example.com" -o "myorg" -e test -z ctmtoken
```

4. The example adds API Key authentication to the API Proxy. This is done 
because the authentication to the Control-M backend will be handled entirely by
the Apigee gateway, so without additional authentication the Control-M 
Automation API would be accessible by anyone.

See the [Secure an API by requiring API keys]https://docs.apigee.com/api-platform/tutorials/secure-calls-your-api-through-api-key-validation#abouttheapiproduct
tutorial for quick steps on how to create a developer user with corrresponding
API Key.

The API Keys must be added to requests as an http header named `apikey`.


## Test a request

We can now start sending requests through the API Gateway.
Let's see what happens when we send a request without specifying the apikey
header:
```
$ curl -s --url https://controlmaapi-eval-test.apigee.net/ctm-outbound-auth/config/servers \
>   | json_reformat
{
    "fault": {
        "faultstring": "Failed to resolve API Key variable request.header.apikey",
        "detail": {
            "errorcode": "steps.oauth.v2.FailedToResolveAPIKey"
        }
    }
}
```

Obviously it failed because we are not allowed to send requests without a valid 
apikey. Once we add that, the request succeeds:
```
$ curl -s --url https://controlmaapi-eval-test.apigee.net/ctm-outbound-auth/config/servers \
>   --header "apikey: ASfAK1k6Qa5UHMAzdTdgMA3PvGm0z8x2" \
>   | json_reformat
[
    {
        "name": "controlm",
        "host": "controlm",
        "state": "Up",
        "message": ""
    }
]
```

Let's see what will happen if we send a session/logout request:
```
$ curl -v --url https://controlmaapi-eval-test.apigee.net/ctm-outbound-auth/session/logout \
  --header "apikey: ASfAK1k6Wa6UGNKzzTdgMA4PvGm0z8t3" 
...
HTTP/1.1 403 Session requests not allowed
```

The API Gateway denies the request like we configured it to. 


## How it works

The PreFlow step of the default proxy is where most of the magic happens:

```
    <PreFlow>
        <Request>
            <!-- Verify API Key -->
            <Step>
                <Name>verify-api-key</Name>
            </Step>
            <!-- Remove API Key from headers so it does not get passed to backend -->
            <Step>
                <Name>remove-apikey-header</Name>
            </Step>
            <!-- Do not allow /session requests -->
            <Step>
                <Condition>(proxy.pathsuffix MatchesPath "/session/**")</Condition>
                <Name>disallow-session-requests</Name>
            </Step>
            <!-- Set some common variables for the API -->
            <Step>
                <Name>api-config</Name>
            </Step>
            <!-- Fetch the Control-M Automation API access token from the cache, if it's there -->
            <Step>
                <Name>api-token-lookup-cache</Name>
            </Step>
            <!-- On cache miss, fetch a new access token -->
            <Step>
                <Condition>lookupcache.api-token-lookup-cache.cachehit == "false"</Condition>
                <Name>api-token-get</Name>
            </Step>
            <!-- On cache miss, put the new access token in the cache -->
            <Step>
                <Condition>lookupcache.api-token-lookup-cache.cachehit == "false"</Condition>
                <Name>api-token-populate-cache</Name>
            </Step>
        </Request>
        <Response/>
    </PreFlow>
```

* First the API Key supplied in the apikey header is verified. Next, that header
is removed from the request so it is not included in the request to the backend.

* Then, any request that starts with /session is denied, because keeping the 
session with the Control-M backend is entirely handled by the API Gateway.

* Some config parameters are then set by a small Javascript, and a lookup for 
the session in the cache is performed. 
If no token was found, a new session token is fetched by a Javascript that 
logs in to the Control-M backend API, and the token is then stored in the cache.

You can review each of the [policies](apiproxy/policies) and 
[scripts](apiproxy/resources/jsc) used above to see how they work in more 
detail.


The PreFlow step of the default target adds the Authorization header to the 
request to pass the session token to the Control-M API backend.
```
    <PreFlow name="PreFlow">
        <Request>
            <Step>
                <!-- Add Authorization header with session token to send to Control-M backend -->
                <Name>add-authorization-header</Name>
            </Step>
        </Request>
        <Response/>
    </PreFlow>
```

