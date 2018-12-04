# Integration with IntelliJ IDEA

1. From the main menu, select "File" > "Settings" and then go to "Tools" > “External Tools”.

2. Click on the **“+”** icon to add a new item and fill in all parameters and options as in the following screenshot (which shows an example for the “*build*” service):

   ![IntelliJ IDEA > External Tools](/601-integration-with-ides-and-code-editors/images/intellij_config.png) 

   * Name : ```Build jobs in json file```
   * Group : ```Control-M Automation API```
   * Program : ```C:\Windows\System32\cmd.exe```
   * Arguments : ```/c ctm build "$FilePath$"```
   * Working directory : ```$ProjectFileDir$```
   
3. Repeat the last step to add any additional services - you can use the "copy" icon on the top to duplicate an existing item. Just type the required command in “Arguments” and update “Name” and “Description” accordingly (keep the rest of parameters as they are). Some examples:

   * Run jobs and monitor via Control-M Workbench : ```/c ctm run "$FilePath$" -i```
   * Deploy jobs to Control-M : ```/c ctm deploy "$FilePath$"```

4. That´s it. You can now right click on a json file containing Control-M job definitions and use the previously defined actions directly from the tool. A console window will open at the bottom showing the results of the operation.

   ![IntelliJ IDEA > Menu](/601-integration-with-ides-and-code-editors/images/intellij_menu.png) 

   *Integration tested with IntelliJ IDEA (Community Edition) 2018.2.5 running on Windows 10*
