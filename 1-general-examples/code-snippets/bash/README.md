## Error handling

### Errors from AAPI

Check if the response has the word `errors` in it, and if so echo a message that relates to the attempted action:

```shell
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )

echo "$login" | grep "errors" > /dev/null && echo "Failed to login" && exit 5
```

### General HTTP errors

To handle general HTTP errors, the return code from curl should be stored to a variable like `$RC` and then evaluated:

```shell
login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )

RC=$?
if [[ $RC -ne 0 ]]; then
  echo "Login request failed"
  exit 5
fi
```

## Password obfuscation

### From a file

If only the password is stored in the `.authfile`:
script:
```shell
username=myuser
endpoint=https://myemhost:8443/automation-api
password=$(cat .authfile)

login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
```
.authfile:
```
myB@dpa$$w0rd
```
If all 3 environment related params are stored in the `.authfile`:

script:
```shell
username=$(grep "^username=" .authfile | cut -d= -f2)
endpoint=$(grep "^endpoint=" .authfile | cut -d= -f2)
password=$(grep "^password=" .authfile | cut -d= -f2)

login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
```

.authfile:
```
username=myuser
endpoint=https://myemhost:8443/automation-api
password=myB@dpa$$w0rd
```

### Prompt for password

If not using a password file, or one is not specified (only for interactive scripts) the user can be prompted to enter a password:

script:
```shell
username=myuser
endpoint=https://myemhost:8443/automation-api
echo -n "Password: "
read -s password

login=$(curl -k -s -H "Content-Type: application/json" -X POST -d "{\"username\":\"$username\",\"password\":\"$password\"}" "$endpoint/session/login" )
```
