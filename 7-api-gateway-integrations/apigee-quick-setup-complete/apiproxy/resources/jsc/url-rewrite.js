// Used to rewrite URLs in the response to route through same proxy.
// URLRewrite policy.

var automationApi = context.getVariable('control-m.automationApi');

var targeturl = automationApi.baseUrl;
var proxyurl = automationApi.proxyUrl;

var re = new RegExp(targeturl,"gi");
response.content = response.content.replace(re, proxyurl);
