# Hold or delete duplicated jobs

## Requirement

After a user accidentally ordered a number of folders as duplicate onto the 
Control-M active environment, a script was developed to automatically identify 
and Hold or Delete these jobs.

## Prerequisites

* Control-M Automation API 9.0.19.140 or higher
* Python 3.6 or higher (lower versions may work but have not been tested)

## Script

A Python script was developed that retrieves a list of jobs from the active 
evironment that matches the Control-M/Server datacenter and Folder specified by
the user. 

The script then identifies all duplicate jobs by *jobname*. For each set of 
duplicates, it considers the job with the lowest orderID as being the original
non-duplicate, and marks the remaining ones as duplicate.

After requesting confirmation, it then Holds or Deletes each duplicate job.

The script also writes an undo-log consisting of ctm cli commands which can be 
run to undo all actions performed by the script.

The complete [script](./scripts/).
