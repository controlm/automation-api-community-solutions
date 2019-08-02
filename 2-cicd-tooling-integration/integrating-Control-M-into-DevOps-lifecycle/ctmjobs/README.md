# 1. Writing json definition

## 1a. Defining the Connection Profiles
Gather the connection information (username, password, host, port, etc) for the source and destination ftp servers.

Create a new file that will store your Connection Profile json code, MFT-conn-profiles.json for example:

```
{
"LocalConn" : {
   "Type" : "ConnectionProfile:FileTransfer:Local",
   "TargetAgent" : "AgentHost",
   "TargetCTM" : "workbench",
   "User" : "controlm",
   "Password" : "local password"
},
"BoE" : {
   "Type" : "ConnectionProfile:FileTransfer:FTP",
   "TargetAgent" : "AgentHost",
   "TargetCTM" : "workbench",
   "HostName": "BoE-FTP",
   "User" : "FTPUser",
   "Password" : {"Secret": "boe-ftp-pass"}
},
"MoD" : {
   "Type" : "ConnectionProfile:FileTransfer:FTP",
   "TargetAgent" : "AgentHost",
   "TargetCTM" : "workbench",
   "HostName": "MoD-FTP",
   "User" : "FTPUser",
   "Password" : {"Secret": "mod-ftp-pass"}
}
}
```

Using the ctm cli utility to create the secrets references by the connection profiles:
```
$ ctm config secret::add boe-ftp-pass <BoE-FTP-Password>
$ ctm config secret::add mod-ftp-pass <MoD-FTP-Password>
```
This makes it so that the passwords are not stored in the json file which will be committed to a git repository

Deploy the connection profiles
```
$ ctm deploy ddos1-conn-profiles.json
```


## 1b. Writing the job definitions

Create a new file that will store the job definition JSON code, [jobs.json](./jobs.json) for example:

```
{
	"Defaults": {
		"Application": "BoEtoMoD",
		"SubApplication": "FileTransform",
		"RunAs": "v19p",
		"Host": "clm-aus-tobcvy"
	},
	"BoEtoMoD": {
		"Type": "Folder",
		"Comment": "Code reviewed by DDOS team",
		"DDO_S1_DOWNLOAD": {
			"Type": "Job:FileTransfer",
			"ConnectionProfileSrc": "BoE",
			"ConnectionProfileDest": "LocalConn",
			"FileTransfers": [{
				"Src": "~/input.csv",
				"Dest": "/tmp/input.csv",
				"TransferOption": "SrcToDest",
				"TransferType": "Binary"
			}]
		},
		"DDO_S1_TRANSFORM": {
			"Type": "Job:Command",
			"Command": "python /home/v19p/transform.py /tmp/input.csv"
		},
		"DDO_S1_VALIDATE": {
			"Type": "Job:Command",
			"Command": "python /home/v19p/validate.py /home/v19p/results.json"
		},
		"DDO_S1_UPLOAD": {
			"Type": "Job:FileTransfer",
			"ConnectionProfileSrc": "LocalConn",
			"ConnectionProfileDest": "MoD",
			"FileTransfers": [{
				"Src": "/home/v19p/results.json",
				"Dest": "~/results.json",
				"TransferOption": "SrcToDest",
				"TransferType": "Binary"
			}]
		},
		"Flow": {
			"Type": "Flow",
			"Sequence": ["DDO_S1_DOWNLOAD",
			"DDO_S1_TRANSFORM",
			"DDO_S1_VALIDATE",
			"DDO_S1_UPLOAD"]
		}
	}
}
```
