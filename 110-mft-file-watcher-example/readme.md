# File watcher example

A File Watcher job enables you to detect the successful completion of a file transfer activity that creates or deletes a file. Once the file is arrived or deleted, the successor job can be triggered. For more information, see the code reference on the [Automation API Code Reference documentation page](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Code+Reference).

## Example

Below a screenshot of the example from the web gui:

![Screenshot](images/file-watcher-flow.png)

The following attributes need to be updated and tailored to your own environment in order to implement this example: 

* ```<APPLICATION>```
* ```<SUB APPLICATION>```
* ```<CONTROLM SERVER>```
* ```<RUN AS USER>```
* ```<HOSTNAME OF MFT AGENT>```
* ```<DESTINATION FILE PATH>```
* ```<SOURCE CONNECTION PROFILE>```
* ```<DESTINATION CONNECTION PROFILE>```
* ```<SOURCE FILE>```
* ```<DESTINATION FILE PATH INCL. FILENAME>```	

Look for these tags in the example and update the value to match your control-m environment.

__NOTE: There are several jobs that lists the content of a directory. Please replace ```ls -l``` with ```dir``` for windows environments.__	
				
This example consists of 2 parts:

### Watch for a file creation

Subfolder FTP_WATCH_CREATE holds 2 job flows:

* The first flow consists of jobs DownloadFiles --> ListFilesAfterDownload: 
	* __DownloadFiles:__ Downloads a file to the <DESTINATION PATH> to trigger the file watcher job. This job needs manual confirmation for demo purposes. After the manual confirmation, the download will start. 
	* __ListFilesAfterDownload:__ This job lists the content of the <DESTINATION PATH> after the download is completed. This job is purely for demo purposes.
* The second flow consists of jobs ListFilesFirst --> WatchForFileCreation --> ListFilesAgain:
	* __ListFilesFirst:__ This job lists the content of the <DESTINATION PATH> before the file watcher job starts. This job is purely for demo purposes.
	* __WatchForFileCreation:__ This is the actual file transfer job that watches for the the a file in the <DESTINATION PATH>.
	* __ListFilesAgain:__ This job lists the content of the <DESTINATION PATH> after the file watcher job is completed. This job is purely for demo purposes.

### Watch for a file to be deleted

Subfolder FTP_WATCH_DELETE has a similar setup:

* The first flow consists of jobs DeleteFile --> ListFilesAfterDelete: 
	* __DeleteFile:__ Deletes a file to the <DESTINATION PATH> to trigger the file watcher job. This job needs manual confirmation for demo purposes. After the manual confirmation, the file gets deleted. 
	* __ListFilesAfterDelete:__ This job lists the content of the <DESTINATION PATH> after the file is deleted. This job is purely for demo purposes.
* The second flow consists of jobs ListFilesFirst --> WatchForFileDeletion --> ListFilesAgain:
	* __ListFilesFirst:__ This job lists the content of the <DESTINATION PATH> before the file watcher job starts. This job is purely for demo purposes.
	* __WatchForFileCreation:__ This is the actual file transfer job that watches for the the a file in the <DESTINATION PATH>.
	* __ListFilesAgain:__ This job lists the content of the <DESTINATION PATH> after the file watcher job is completed. This job is purely for demo purposes.
