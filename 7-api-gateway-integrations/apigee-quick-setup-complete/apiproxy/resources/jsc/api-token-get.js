var automationApi = context.getVariable('control-m.automationApi');

/**
 * Retrieve an access token for the Control-M Automation API
 */
function getAccessToken() {
  var bodyObj = {
    'username': automationApi.username,
    'password': automationApi.password
  };
  loginUrl = automationApi.baseUrl + '/session/login';

  var headers = {'Content-Type' : 'application/json' };
  var req = new Request(loginUrl, 'POST', headers, JSON.stringify(bodyObj));
  var exchange = httpClient.send(req);

  // Wait for the asynchronous POST request to finish
  exchange.waitForComplete();

  if (exchange.isSuccess()) {
    var responseObj = exchange.getResponse().content.asJSON;

    if (responseObj.error) {
      throw new Error(responseObj.error_description);
    }

    return responseObj.token;
  } else if (exchange.isError()) {
    throw new Error(exchange.getError());
  }
}

context.setVariable('control-m.apiAccessToken', getAccessToken());
