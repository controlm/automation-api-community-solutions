# Notepad++ additional examples

Here are additional examples of commands to invoke the Control-M Automation API. These have been created and configured for Notepad++, but could potentially be adapted for any IDE tool or code/text editor.

To integrate them with Notepad++ you have two options:

   1. Do it manually, following the instructions in the [**integration-with-notepad++.md**](/601-integration-with-ides-and-code-editors/integration-with-notepad++.md) file. 
   
   2. Do it via downloading the following ZIP FILE

<br>

### Build workflow
```cmd /c ctm build "$(FULL_CURRENT_PATH)"```

### Deploy workflow

```cmd /c ctm deploy "$(FULL_CURRENT_PATH)"```

### Run workflow

```
NPP_CONSOLE 0
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(NAME_PART)_runid.tmp"
cmd /c ctm run "$(FULL_CURRENT_PATH)" > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```

* After completion, it will open a temp file containing the command output (which includes the ***runId***).

### Run workflow

* After completion, it will open a temp file containing the command output (which includes the ***runId***).

```
NPP_CONSOLE 0
set local TMP_FILE="$(CURRENT_DIRECTORY)\$(NAME_PART)_runid.tmp"
cmd /c ctm run "$(FULL_CURRENT_PATH)" > $(TMP_FILE) 2>&1
NPP_OPEN $(TMP_FILE)
cmd /c del $(TMP_FILE)
```


