# Integration with Notepad++

1. Open Notepad++ and check under the “Plugins” menu that you have the “Plugin Manager” installed. If not, install it by following this [instructions](https://bruderste.in/npp/pm/#install).

2. From the main menu, go to “Plugins” > “Plugin Manager” > “Show Plugin Manager”. In “Available Plugins”, search for “NppExec”, select it and click on “Install”.

3. Once installed, go to “Plugins” > “NppExec” > “Execute”. Type the command for the Control-M Automation API service you want to invoke,  then save and assign a name. E.g. for the "build" service the full command line would be:

   ```cmd /c ctm build "$(FULL_CURRENT_PATH)"```

4. Repeat the last step to define any additional operations (*see below for more examples*).

5. Go to “Plugins” > “NppExec” and make sure you have the following options selected:

   - Show Console Dialog
   - Console Command History
   - No internal messages

6. Go to “Plugins” > “NppExec” > “Advanced Options” and select the “Place to the Macros submenu” option, and “[Console]” > “Visible (on start)” = “No”.

7. From the same window, select each script, type the name you want to appear in the menus (e.g. “Build jobs in json file” for “ctm_build”) and click on “Add/Modify”. Repeat the same steps for any additional item you want to add to the menu.

8. At this point, you can already access all these functions by clicking on “Macro” in the main menu. To add all these functions to a context menu (accessible via right-click directly on the json file), go to “Settings” > “Edit Popup ContextMenu”. A new file is opened which contains the details for the appearance of the context menu.

9. If you right click on the file (“contextMenu.xml”) you will see the current format of the context menu, and in the file itself you can check the code that defines the text to be shown and the actions/plugins to invoke when each item is selected. The lines with “<Item id="0"/>“ are separators.

10. Go to any part of the file where you want to include your new sub-menu for Control-M Automation API, and include the following lines (change the content of “PluginCommandItemName” on each line according to your values defined in step 8, and add more lines for more menu options if required).

      ```
	<!--
	Control-M Automation API integration
    -->
    <Item FolderName="Control-M Automation API" PluginEntryName="NppExec"
    PluginCommandItemName="Build jobs in json file" />
    <Item FolderName="Control-M Automation API" PluginEntryName="NppExec"
    PluginCommandItemName="Run jobs in json file" />
    <Item FolderName="Control-M Automation API" PluginEntryName="NppExec"
    PluginCommandItemName="Deploy jobs in json file" />
    <Item id="0"/>
      ```

11. Restart Notepad++. Now you can right click on a json file and use the previously defined actions directly from the tool. A console window will open at the bottom showing the results of the operation.


*Integration tested with Notepad++ 7.5.1 (32-bit) and NppExec plugin 0.6.*
