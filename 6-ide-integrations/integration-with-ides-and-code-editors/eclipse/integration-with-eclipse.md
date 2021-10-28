# Integration with Eclipse

1. From the main menu, select "Run" > "External Tools" > "External Tools Configurations".

2.	In the left panel, right click on "Program" and select "New Configuration".

3. Type a "Name" at the top and fill in all parameters as in the following screenshot (which shows an example for the "*build*" service):

   ![Eclipse Config](/6-ide-integrations/integration-with-ides-and-code-editors/images/eclipse_config.png)
 
   * Name : ```Control-M - Build jobs in json file```
   * Location : ```C:\Windows\System32\cmd.exe```
   * Arguments : ```/c ctm build ${resource_loc}```

4. Before clicking on "Apply" to save the changes, go to the "Common" tab and make sure you have the following options selected:

   * "Display in favorites menu" > "External Tools"
   * "Allocate console"
   * "Launch in background"

5. Repeat the last steps to add any additional services - you can use the "duplicate" icon at the top. Just type the required command in "Arguments" and update "Name" accordingly (keep the rest of parameters as they are). Some examples:

   * Run jobs and monitor via Control-M Workbench : ```/c ctm run "${resource_loc}" -i -e workbench```
   * Deploy jobs to default Control-M environment : ```/c ctm deploy "${resource_loc}"```
   * Deploy jobs to Control-M environment "PreProd" : ```/c ctm deploy "${resource_loc}" -e PreProd```
      
6. That´s it. After clicking on "Apply" and closing the window, you can now select a json file containing Control-M job definitions and use any of the previously defined actions via "Run" > "External Tools". A console window will open showing the results of the operation.

   As we also added those operations as favorites, you can launch them too from the “Run external commands” icon at the top, as shown in the following screenshot.

   ![Eclipse Menu](/6-ide-integrations/integration-with-ides-and-code-editors/images/eclipse_menu.png) 

   *Integration tested with Eclipse IDE for Java Developers 2018-09 (4.9.0) running on Windows 10*
