# Notepad++ additional examples

Here are additional examples of commands to invoke the Control-M Automation API. These have been created and configured for Notepad++, but could potentially be adapted for any IDE tool or code/text editor.
   
To integrate them with Notepad++ you have two options:

   1. Do it manually, following the instructions in the [**integration-with-notepad++.md**](/601-integration-with-ides-and-code-editors/integration-with-notepad++.md) file. 
   
   2. Do it via downloading the following ZIP FILE

<br>

> Note that all operations are performed by default on the current Automation API environment (as displayed via "**ctm env show**"). If you want to create operations for multiple environments, you can use the "**-e \<environment>**" option.

### Build workflow
```
cmd /c ctm build "$(FULL_CURRENT_PATH)"
```

### Deploy workflow
```
cmd /c ctm deploy "$(FULL_CURRENT_PATH)"
```

### Run workflow
```
NPP_CONSOLE 0
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(NAME_PART)_runid.tmp"
cmd /c ctm run "$(FULL_CURRENT_PATH)" > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* After completion, it will open a temp file containing the command output (which includes the **runId**).

### Build on Control-M Workbench
```
cmd /c ctm build "$(FULL_CURRENT_PATH)" -e workbench
```

### Run on Control-M Workbench
```
cmd /c ctm run "$(FULL_CURRENT_PATH)" -i -e workbench
```
* After completion it will open a browser with the Workbench web interface to monitor the execution.

### Test Deploy Descriptor
```
NPP_CONSOLE 0
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(NAME_PART)_transform.tmp"
cmd /c ctm deploy transform "$(FULL_CURRENT_PATH)" "$(#2)" > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* You should have two files open (in two tabs): first the workflow and second the deploy descriptor.
* Run the action from the workflow tab.
* It will open a temp file containing how the workflow will look after applying the deploy descriptor.

### Deploy workflow using a Deploy Descriptor
```
cmd /c ctm deploy "$(FULL_CURRENT_PATH)" "$(#2)"
```
* You should have two files open (in two tabs): first the workflow and second the deploy descriptor.
* Run the action from the workflow tab.

### Check workflow status
```
NPP_CONSOLE 0
set local FNAME_FIX ~ strreplace "$(NAME_PART)" "_runid" ""
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(FNAME_FIX)_status.tmp"
cmd /c ctm run status $(CURRENT_WORD) > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* Select the runId before running the action (e.g. “1a708abc-fbc2-4802-a385-8b2311177275”).
* This action is usually executed from the temp file generated when running a workflow.
* It will open a temp file containing the workflow status.

### Check folder status
```
NPP_CONSOLE 0
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(CURRENT_WORD)_status.tmp"
cmd /c ctm run jobs:status::get -s "folder=$(CURRENT_WORD)" > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* Select the folder name before running the action.
* It will open a temp file containing the folder status.
* If several instances of the folder have been ordered, it will include the statuses for all of them.
* If no text is selected, it will retrieve the status for all active folders and jobs.

### Check job status
```
NPP_CONSOLE 0
set local FNAME_FIX ~ strreplace "$(CURRENT_WORD)" ":" "_"
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(FNAME_FIX)_status.tmp"
cmd /c ctm run jobs:status::get -s "jobid=$(CURRENT_WORD)" >> $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* Select the jobId before running the action (e.g. “ctmsrv: 0018z”).
* This action is usually executed from the temp file generated when showing a workflow or folder status.
* It will open a temp file containing the job status.

### Show job log
```
NPP_CONSOLE 0
set local FNAME_FIX ~ strreplace "$(CURRENT_WORD)" ":" "_"
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(FNAME_FIX)_log.tmp"
cmd /c ctm run job:log::get $(CURRENT_WORD) > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* Select the jobId before running the action (e.g. “ctmsrv: 0018z”).
* This action is usually executed from the temp file generated when showing a workflow, folder or job status.
* It will open a temp file containing the job log.

### Show job output
```
NPP_CONSOLE 0
set local FNAME_FIX ~ strreplace "$(CURRENT_WORD)" ":" "_"
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(FNAME_FIX)_output.tmp"
cmd /c ctm run job:output::get $(CURRENT_WORD) > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* Select the jobId before running the action (e.g. “ctmsrv: 0018z”).
* This action is usually executed from the temp file generated when showing a workflow, folder or job status.
* It will open a temp file containing the job output.

### Import selected folder
```
NPP_CONSOLE 0
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(CURRENT_WORD)_import.tmp"
cmd /c ctm deploy jobs::get -s "ctm=*&folder=$(CURRENT_WORD)" > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```
* Select the folder name before running the action.
* It will open a temp file containing the imported folder.
* Import could also be retrieved in XML format (ctm deploy jobs::get XML -s “…”).

### Delete selected folder
```
set local FOLDER="$(CURRENT_WORD)"
INPUTBOX "Please confirm you want to delete the Folder by typing the Control-M/Server
name" : "CTM/Server = " : ctmsrv
cmd /c ctm deploy folder::delete $(INPUT) "$(FOLDER)"
```
* Select the folder name before running the action.
* A popup will appear asking for confirmation, where you have to type the Control-M/Server name.
* Replace “ctmsrv” below with your Control-M/Server name to have its value by default.
