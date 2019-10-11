// Used to rewrite URLs in the response to route through same proxy.
// URLRewrite policy.

var targeturl = 'https://ENDPOINT:8443/automation-api';
var reportingurl = 'https://REPORTING:8443/automation-api';
var proxyurl = 'https://controlmaapi-eval-test.apigee.net/ctm-routing';

var re = new RegExp(targeturl,"gi");
response.content = response.content.replace(re, proxyurl);
var re = new RegExp(reportingurl,"gi");
response.content = response.content.replace(re, proxyurl);

