# Integration with Notepad++

1. From the main menu, check under “Plugins” that you have the “Plugin Manager” installed. If not, install it by following this [instructions](https://bruderste.in/npp/pm/#install).

2. Go to “Plugins” > “Plugin Manager” > “Show Plugin Manager”. In the “Available” tab, search for “NppExec”, select it and click on “Install”.

3. Go to “Plugins” > “NppExec” > “Execute”. Type the command for the Control-M Automation API service you want to invoke, then save and assign a name as in the following screenshot (which shows an example for the "*build*" service):

   ![Notepad++ > Config 1](/601-integration-with-ides-and-code-editors/images/notepad++_config_1.png)

   * Name : ```ctm_build```
   * Command : ```cmd /c ctm build "$(FULL_CURRENT_PATH)"```
   
4. Repeat the last step to add any additional services - some examples:

   * Run jobs and monitor via Control-M Workbench : ```/c ctm run "$(FULL_CURRENT_PATH)" -i -e workbench```
   * Deploy jobs to default Control-M environment : ```cmd /c ctm deploy "$(FULL_CURRENT_PATH)"```
   
5. Go to “Plugins” > “NppExec” and make sure you have the options "Console Command History" and "No internal messages" selected.

6. Go to “Plugins” > “NppExec” > “Advanced Options” and select the “Place to the Macros submenu” option, and “[Console]” > “Visible (on start)” = “No”.

7. From the same window, select each "Associated script", type the "Item name" you want to show in the menus and click on “Add/Modify”. Repeat the same steps for any additional item you want to add to the menu.

   ![Notepad++ > Config 2](/601-integration-with-ides-and-code-editors/images/notepad++_config_2.png)

   At this point, you can already access all these operations by clicking on “Macro” in the main menu.

8. If you want to add all these functions to a context menu (accessible via right-click on a file), go to “Settings” > “Edit Popup ContextMenu”. A new file is opened which contains the details for the appearance of the context menu.

   Go to any part of the file where you want to include your new sub-menu for Control-M Automation API, and add a line for each "Item name" defined before following the format shown in this example:
   
    ```
    <!--
    Control-M Automation API integration (via NppExec plugin)
    -->
    <Item FolderName="Control-M Automation API" PluginEntryName="NppExec" PluginCommandItemName="Build workflow" />
    <Item FolderName="Control-M Automation API" PluginEntryName="NppExec" PluginCommandItemName="Run workflow" />
    <Item FolderName="Control-M Automation API" PluginEntryName="NppExec" PluginCommandItemName="Deploy workflow" />
    <Item id="0"/>
    ```
   
   where:
   
   * ```FolderName``` is the name of the common sub-menu for Control-M Automation API
   * ```PluginCommandItemName``` corresponds to each "Item name" previously defined via NppExec
   * The lines ```<Item id="0"/>``` are menu separators

9. Restart Notepad++. You can now access any of the previously defined operations either via “Macro” in the main menu or by right clicking on a file. A console window will open at the bottom showing the results of the operation.

> If you want to add additional Automation API operations as those in the screenhost below, check the "notepad++-additional-examples.md" file.

   ![Notepad++ > Menu](/601-integration-with-ides-and-code-editors/images/notepad++_menu.png)

   *Integration tested with Notepad++ 7.5.9 (64-bit) and NppExec plugin 0.6 running on Windows 10*
