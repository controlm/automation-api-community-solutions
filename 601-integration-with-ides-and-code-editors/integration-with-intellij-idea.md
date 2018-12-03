# Integration with IntelliJ IDEA

1. From the main menu, go to “File” > “Settings”.

2. Now go to “Tools” > “External Tools”.

3. Click on the “+” icon to add a new item and fill in all parameters and options as in the following screenshot (which shows an example for the “build” service):

   ![IntelliJ IDEA > External Tools](/601-integration-with-ides-and-code-editors/images/intellij_ext_tools.png) 

   Name : ```Build jobs in json file```\
   Group : ```Control-M Automation API```\
   Program : ```C:\Windows\System32\cmd.exe```\
   Arguments : ```/c ctm build "$FilePath$"```\
   Working directory : ```$ProjectFileDir$```
   
4. Repeat the last step to add any additional services (you can use the "copy" icon on the top to duplicate existing items). Just type the required command in the “Parameters” field and update the “Name” and “Description” accordingly. For example:

   ```/c ctm run "$FilePath$" -i```   run jobs and monitor via Control-M Workbench
   ```/c ctm deploy "$FilePath$"```   deploy jobs to Control-M

5. That´s it. You can now right click on a json file containing Control-M job definitions and use the previously defined actions directly from the tool. A console window will open at the bottom showing the results of the operation.

*Integration tested with IntelliJ IDEA (Community Edition) 2018.2.5 running on Windows 10*
