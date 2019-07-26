import requests
import urllib3

urllib3.disable_warnings()  # disable warnings when creating unverified requests

# -----------------
#Control-M Automation API server address
#Control-M server
#endPoint: the URL of Control-M Automation API server
#ctms: the name of Control-M Server
# -----------------
endPoint = 'xxxx'
ctms = 'xxxx'

# -----------------
#the login credential to your Control-M Automation API server
# -----------------
username = 'xxxx'
password = 'xxxx'
# pass the credential as params
credentialAAPI = {
        "username": username,
        "password": password
}
# -----------------
# login to Automation API server and get the token
# -----------------
r_login = requests.post(endPoint + '/session/login', json=credentialAAPI, verify=False)

#print(r_login.status_code)
if r_login.status_code != requests.codes.ok:
    exit(1)
else:
    print("You have connected to Automation API server.")
    token = r_login.json()['token']

# -----------------
# Check the status of the Agents and build the sets
# config server:agents::get
# -----------------
search_criteria = ctms + "/agents?agent=*"
urlAgentAvailabilityCheck = endPoint + '/config/server/' + search_criteria

r_responce = requests.get(urlAgentAvailabilityCheck,
                           headers={'Authorization': 'Bearer ' + token},
                           verify=False)
if r_responce.status_code != requests.codes.ok:
    print(r_responce.status_code)
    exit(1)
else:
    #agentDict = {}
    # the sets which keep the respective Agents
    agentAvailableSet = set()
    agentUnavailableSet = set()
    agentDisabledSet = set()
    agentDiscoveringSet = set()

    #print(json.dumps(r_responce.json(), indent=4))

    Agents = r_responce.json()['agents']
    for agent in Agents:
        #print(agent)
        #agentDict[agent["nodeid"]] = agent["status"]
        if agent["status"] == "Available":
            agentAvailableSet.add(agent["nodeid"])
        elif agent["status"] == "Unavailable":
            agentUnavailableSet.add(agent["nodeid"])
        elif agent["status"] == "Disabled":
            agentDisabledSet.add(agent["nodeid"])
        else:
            agentDiscoveringSet.add(agent["nodeid"])

    # -----------------
    # print out the Agent status
    # -----------------
    print("You have " + str(len(agentAvailableSet)) + " Agents in Available status: ")
    for x in agentAvailableSet:
        print(x)
    print("")

    print("You have " + str(len(agentUnavailableSet)) + " Agents in Unavailable status: ")
    for x in agentUnavailableSet:
        print(x)
    print("")

    print("You have " + str(len(agentDisabledSet)) + " Agents in Disabled status: ")
    for x in agentDisabledSet:
        print(x)
    print("")

    print("You have " + str(len(agentDiscoveringSet)) + " Agents in Discovering status: ")
    for x in agentDiscoveringSet:
        print(x)
    print("")

# -----------------
# logout from Automation API
# -----------------
endpoint = endPoint + '/session/logout'
r_logout = requests.post(endpoint,
                             headers={'Authorization': 'Bearer ' + token},
                             verify=False)

print(r_logout.status_code)
if r_logout.status_code != requests.codes.ok:
    exit(1)
else:
    print("You have disconnected from Automation API server.")
