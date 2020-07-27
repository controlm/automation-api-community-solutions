# Download the helper library from https://www.twilio.com/docs/python/install
from twilio.rest import Client
import getopt, os, sys, time

# Your Account Sid and Auth Token from twilio.com/console
# DANGER! This is insecure. See http://twil.io/secure


def usage():
    print("\t-f, --authfile\t\tPath of text file with Twilio Credentials")
    print("\t-m, --message\t\tMessage text to send")
    print("\t-n, --number\t\tPhone Number to send message to")
    print("\t-s, --account_sid\tTwilio Account")
    print("\t-t, --auth_token\tTwilio Authorization token")

def main(argv):
    smsText = ""
    smsNumber = ""
    account_sid = ""
    auth_token = ""
    authfile = ""

    try:
        opts, args = getopt.getopt(argv, "hf:m:n:s:t:",
                                   ["authfile=", "message=", "number=", "account_sid=", "auth_token="])
    except getopt.GetoptError:
        usage()
        sys.exit(1)

    for opt, arg in opts:
       if opt == '-h':
          usage()
          sys.exit(0)
       elif opt in ("-f", "--authfile"):
           authpath: string = arg
           authfile = open(authpath,"r")
           account_sid = authfile.readline()
           auth_token = authfile.readline()
       elif opt in ("-m", "--message"):
          smsText: string = arg
       elif opt in ("-n", "--number"):
          smsNumber: string = arg
       elif opt in ("-s", "--account_sid"):
          account_sid: string = arg
       elif opt in ("-t", "--auth_token"):
          auth_token: string = arg

    client = Client(account_sid, auth_token)
    message = client.messages \
        .create(
        body=smsText,
        from_='+12183967406',
        to=smsNumber
    )

    print(message.sid)


if __name__ == "__main__":
    main(sys.argv[1:])
