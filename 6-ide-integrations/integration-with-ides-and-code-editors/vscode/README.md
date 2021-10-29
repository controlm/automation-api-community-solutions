# Integration with Visual Studio Code

This an example to trigger the Control-M Automation API command line via Visual Studio Code custom tasks. To import the provided sample task definitions:

1. From VS Code, press F1 (or Ctrl+Shift+P) and type "tasks", select "Tasks: Open User Tasks" and then "Others".
2. Replace the default content with the ["tasks_basic.json"](/6-ide-integrations/integration-with-ides-and-code-editors/vscode/tasks_basic.json) file. (*If you already have your own "tasks" or "inputs" defined in the tasks.json file, update it by adding the new entries instead of overwriting the file*). 
3. Before saving and closing the "tasks.json" file, go to the line after the comment "*Edit the following line to use your own Automation API environment names*" - and update accordingly.

And that´s it. The "tasks_basic.json" file includes two tasks:

* `ctm aapi - build/deploy/run`

    Select the operation and the Automation API environment.

* `ctm aapi - deploy using descriptor`

    Enter the Deploy Descriptor file name you want to use (*by default it looks in the folder where the workflow definition resides, but you can also specify a relative file path*), and then select the AAPI environment.

The task definitions have been configured to enable working with multiple AAPI environments. If you only have one AAPI environment or you always want to use the default one, you could skip the environment selection by 1) removing the "id" = "ctmEnv" section in "inputs" and 2) editing each task command to use the default environment by removing "-e ${input:ctmEnv}".

For more information regarding custom tasks configuration in VS Code: https://code.visualstudio.com/docs/editor/tasks#_custom-tasks

## Keyboard shortcuts

Optionally, you can create your custom keyboard shortcuts to access the previously defined tasks. A sample "keybindings.json" file is provided.

1. Go to "File" > "Preferences" > "Keyboard Shortcuts".
2. Click on the top right icon which shows the mouse-over message "Open Keyboard Shortcuts (JSON)"
3. Replace the default content with the "keybindings.json" file (*if you already had custom shorcuts, edit the file accordingly*).

The provided example defines "Ctrl+Alt+T" to open all available tasks, and "Alt+C" to directly trigger the "build/deploy/run" task. You can change it to use your own keyboard shortcuts (make sure there are no conflicts with default VS Code shortcuts).

For more information regarding keyboard shortcuts in VS Code: https://code.visualstudio.com/docs/getstarted/keybindings

## Using an Extension to run Tasks

You can also install an extension to manage and launch the previously created tasks. Simply open "Extensions" (Ctrl+Shift+X) and search for "task" to install any extension of your choice.

As an example, I use an extension called "Task Runner" (by Sana Asaji), which creates an additional drop-down menu in the VS Code Explorer Pane with all the available tasks.

## Running a Task

You can run the previously defined tasks in different ways:

* From the global menu bar, select "Terminal" and then "Run Task".
* Using the keyboard shortcut "Ctrl+P" and then typing "task".
* Using the keyboard shortcuts previously defined (e.g. "Ctrl+Alt+T" to show all tasks).
* From a Task Runner extension.

Once a task is executed, any resulting output or error messages will be shown in the VS Code integrated terminal.

## Additional Tasks

Instead of the "tasks_basic.json" file, you can use "tasks_extended.json", which includes additional Automation API operations.

> **The tasks defined in this file work only when VS Code is installed on Windows**. 

* *For other OS such as macOS or Linux, you would need to adapt the commands and syntax used in each "command" task property.*

* *Please be also aware that the "windows" and "presentation" sections would apply to all tasks defined in the JSON file. If you have additional custom tasks that could be affected by these settings, you will have to include both sections in *each* task definition in the JSON file, as in the "tasks_basic".json example.*

To import these tasks just follow the same instructions as above, but using the content of the "tasks_extended.json" file instead.

For the tasks that create a temporary file showing the results of an AAPI service, the file itself is immediately deleted - but the content remains available in a VS Code tab until it is manually closed.

The "tasks_extended.json" file includes the following additional tasks:

* `ctm aapi - test deploy descriptor`

    Enter the Deploy Descriptor file name (and select the AAPI environment). It will open a new tab with the resulting workflow.

* `ctm aapi - run (show runId)`

    Same as the "run" operation, but it will also open a new tab with the workflow execution details, including the "runId".

* `ctm aapi - workflow status`

    You must first highlight a "runId" (e.g. in the resulting tab from the previous task). It will open a new tab with the status details for all the folders/jobs in the workflow.

* `ctm aapi - job status/log/output`

    You must first highlight a "jobId" (e.g. in the resulting tab from the previous task). After selecting the operation, it will open a new tab with the status, log or output.

* `ctm aapi - job actions`

    You must first highlight a "jobId" and then select the required job action (*hold, free, rerun, setToOk, runNow, kill, delete, undelete, waitingInfo, get*).

* `ctm aapi - folder import`

    You must first highlight a "folder" name. It will open a new tab with the JSON definition of the imported folder.

* `ctm aapi - folder delete`

    You must first highlight a "folder" name. After typing the Control-M/Server name, the folder will be deleted.

<br>

![Visual Studio Code](/6-ide-integrations/integration-with-ides-and-code-editors/images/vscode.png) 

*Integration tested with Visual Studio Code 1.61.2 running on Windows 10*
