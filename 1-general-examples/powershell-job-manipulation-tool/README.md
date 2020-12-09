# **Display job information and operate on jobs**
This Powershell script uses the ctm command line interface to
display job information in a compact format. You can then 
perform a limited number of operator actions on the jobs such as:
* Bypass job requirements
* Display details
* Select an environment
* Kill a job
* View Log
* View Output
* Rerun and bypass a job in a single request
* Rerun a job

You can choose any environment defined for the ctm cli and you can 
switch among environments at any time. This gives you the flexibility 
to work on jobs in all authorized environments within a single session.

It is hoped that community input will expand the capabilities of this script.

This script was developed and tested using Powershell 7.0.2.

To execute:
```
pwsh <path>\dj.ps1
```
