# SSH Key Rotation with Postman

## Variables

| Variable | Value | Mapped Parameter | Default |
| ---- | ---- | ---- | ---- |
| baseUrl | https://ctm-em/automation-api | baseUrl | Yes | 
| SSH_USER_NAME | planets | :user | Yes | 
| SSH_KEY_NAME |  |  | No | 
| SSH_KEY_PASSPHRASE | W3lcome |  | Yes | 
| SSH_KEY_FORMAT | OpenSSH |  | Yes | 
| SSH_KEY_TYPE | ECDSA |  | Yes | 
| SSH_KEY_BITS | 521 |  | Yes | 
| CTM_Server | ctm-lin-srv |  :server | Yes | 
| CTM_AGENTLESS_HOST |  | :agent | No | 


## Create SSH Key

URL: {{baseUrl}}/config/server/:server/sshkey/add


``` json
{
  "keyName": "{{SSH_KEY_NAME}}",
  "passPhrase": "{{SSH_KEY_PASSPHRASE}}",
  "format": "{{SSH_KEY_FORMAT}}",
  "type": "{{SSH_KEY_TYPE}}",
  "bits": "{{SSH_KEY_BITS}}",
  "async": "false"
}
```

## get SSH Public Key

URL: {{baseUrl}}/config/server/:server/sshkey/{{SSH_KEY_NAME}}/{{SSH_KEY_PASSPHRASE}}

## update RunAs user

URL: {{baseUrl}}/config/server/:server/runasuser/:agent/:user

```json
{
  "key": {
    "keyname": "{{SSH_KEY_NAME}}",
    "passphrase": "{{SSH_KEY_PASSPHRASE}}"
  }
}
```

## Test RunAs user with SSH Key

URL: {{baseUrl}}/config/server/:server/runasuser/:agent/:user/test

```json
{
  "key": {
    "keyname": "{{SSH_KEY_NAME}}",
    "passphrase": "{{SSH_KEY_PASSPHRASE}}"
  }
}
```
