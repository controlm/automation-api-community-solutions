# Apigee API gateway routing example

An API Gateway can be configured such that features are applied to only 
particular services, routes or requests. 

This example takes the [add-aapi-service-to-apigee-gateway](https://github.com/controlm/automation-api-community-solutions/tree/master/7-api-gateway-integrations/add-aapi-service-to-apigee-gateway)
example and adds an additional route, which sends /reporting/ requests to a 
different Automation API endpoint of a distributed Control-M environment. This 
helps distrubute the workload and moves potential long-running reports off the 
main GUI server where end users are logged in to.

## 1. Add multiple targets

Under the Targets section in the API Proxy definition, you can add targets urls.
Here we have added a "reporting" target in addition to the existing "default" 
one:

![Create new Proxy - step 1][multiple-targets]


## 2. Add routing rule

After defining the additional target(s), the routing rules at the end of the 
proxy definition can be used to determine under which condition a request will 
be routed to a particular target. For example:

```
    <RouteRule name="default">
        <Condition>(proxy.pathsuffix MatchesPath "/reporting/**")</Condition>
        <TargetEndpoint>reporting</TargetEndpoint>
    </RouteRule>
    <RouteRule name="default">
        <TargetEndpoint>default</TargetEndpoint>
    </RouteRule>
```

When the request path starts with /reporting/, the request will be routed to the 
`reporting` target. All other requests will be routed to the default target.
The order of routing rules is important, as the first one that matches will be 
chosen.

[multiple-targets]: images/multiple-targets.png "Add multiple targets"


## Setup

This example includes the [apiproxy](apiproxy) directory containing all the 
files required to set up teh example API Proxy using apigeetool.
Follow these steps:

1. Copy the `apiproxy` directory from this example to a location on the machine
   where you have the apigeetool installed.

2. Edit the following two files which contain the urls for the two target 
endpoints.
```
apiproxy/resources/jsc/URLRewrite.js
apiproxy/targets/default.xml
```

Change them from `https://ENDPOINT:8443/automation-api` and 
`https://REPORTING:8443/automation-api` to the correct URLs for your main and 
secondary distributed Control-M Automation API endpoints.


3. From the parent directory where you copied the `apiproxy` directory, run the
   following command:
```
apigeetool deployproxy -u "me@example.com" -o "myorg" -n ctm-routing -e test
```

Your username is the e-mail address with which you login to Apigee. The 
organisation will be listed there as well. The environment (-e) option specifies
in which environment to deploy the proxy. 
For more information about apigeetool options go 
[here](https://www.npmjs.com/package/apigeetool#deployproxy).

This command deploys the `ctm-routing` API Proxy to your Apigee 
environment. If a proxy with the same name already exists, a new revision will 
be added to that proxy.

