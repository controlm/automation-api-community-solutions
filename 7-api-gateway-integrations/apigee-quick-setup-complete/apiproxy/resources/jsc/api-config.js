/**
 * Sets Automation API endpoint login credentials and url
 */
context.setVariable('control-m.automationApi', {
  // Control-M Automation API credentials
  username: 'ctmuser',
  password: 'ctmpass',

  // Automation API endPoint URL:
  baseUrl: 'https://ENDPOINT:8443/automation-api',
  proxyUrl: 'https://YOURAPIGEEACCOUNT.apigee.net/controlm'
});
