# hold-or-delete-duplicated-jobs.py

This script takes a Control-M/Server datacenter name and folder name as 
arguments, and checks the active Control-M environment for duplicate jobs from 
that folder. After user confirmation, it can then either Hold those jobs or mark
them for deletion.

## Usage

```
usage: hold-or-delete-duplicated-jobs.py [-h] -u USERNAME [-pf PWFILE] [-i]
                                         (-o | -d) -s CTM -f FOLDER

Identifies jobs ordered as duplicate for a given Control-M datacenter and
Folder, and Holds or Deletes the job.

optional arguments:
  -h, --help            show this help message and exit
  -u USERNAME, --username USERNAME
                        Username to login to Control-M/Enterprise Manager
  -pf PWFILE, --pwfile PWFILE
                        The file that contains the password to login to
                        Control-M/Enterprise Manager
  -i, --insecure        Disable TLS certificate verification
  -o, --hold            Hold the jobs
  -d, --delete          Mark the jobs for deletion
  -s CTM, --ctm CTM     Control-M datacenter on which the jobs reside
  -f FOLDER, --folder FOLDER
                        Folder name from which the jobs were ordered
```

For example, if a user accidentally ordered the folder Samples twice, the 
Control-M administrator could run the following command to automatically Hold
the duplicate jobs, by running:

```
hold-or-delete-duplicated-jobs.py -i -u emuser -s controlm -f Samples --hold
```

The output would look similar to the following:

```
$ ./hold-or-delete-duplicated-jobs.py -i -u emuser -s controlm -f Samples --hold
Password:
34 total jobs found
17 considered as duplicate based on jobname

This will hold 17 jobs on the Control-M active environment.
Do you want to continue? Yes or No: Y
controlm:001ki was successfully held
controlm:001kg was successfully held
controlm:001kj was successfully held
controlm:001ke was successfully held
...
```

## Undo file

The script writes an undo file, which contain the ctm cli commands that will 
undo each action that the script took. For example, the above run would create 
the following file:

```
$ cat undofile.txt
ctm run job::free clm-aus-tobcvy:001ki
ctm run job::free clm-aus-tobcvy:001kg
ctm run job::free clm-aus-tobcvy:001kj
ctm run job::free clm-aus-tobcvy:001ke
...
```

## Important Notes

* Jobs that have been held using the Hold request will remain in this state on
  the Control-M active environment *indefinitely*. It is recommended to either 
  Delete or Free these jobs within 1 day to ensure they will be cleaned by the
  next New Day procedure.

* The Delete request does not actually delete a job from the active environment,
  but instead sets a Deletion flag. It is ignored by Control-M's scheduling 
  processes and removed by the next New Day procedure. Until that time, an 
  Undelete can still be performed to undo the Delete action.

* Errors when modifying the Control-M active jobs in a production environment 
  can have significant consequences. *Always* test the behaviour of this example 
  script in a test environment.
