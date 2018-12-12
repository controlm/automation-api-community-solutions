# File watcher example

A file watcher job can be used to watch for a file to arrive. Once the file is arrived, the successor job can be triggered. For more information, see the code reference on the [Automation API Code Reference documentation page](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Code+Reference).

## Example

This example consists of 2 parts:

### Watch for a file creation

Subfolder FTP_WATCH_CREATE holds 2 job flows:

* The first flow consists of jobs DownloadFiles --> ListFilesAfterDownload: 
	* DownloadFiles: Downloads a file to the <DESTINATION PATH> to trigger the file watcher job. This job needs manual confirmation for demo purposes. After the manual confirmation, the download will start. 
	* ListFilesAfterDownload: This job lists the content of the <DESTINATION PATH> after the download is completed. This job is purely for demo purposes.
* The second flow consists of jobs ListFilesFirst --> WatchForFileCreation --> ListFilesAgain:
	* ListFilesFirst: This job lists the content of the <DESTINATION PATH> after the download is completed. This job is purely for demo purposes.
	* WatchForFileCreation: This is the actual file transfer job that watches for the the a file in the <DESTINATION PATH>.
	* ListFilesAgain: This job lists the content of the <DESTINATION PATH> after the download is completed. This job is purely for demo purposes.

### Watch for a file to be deleted
