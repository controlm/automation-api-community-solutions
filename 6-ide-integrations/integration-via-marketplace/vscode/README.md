# BMC Software Control-M Job-As-Code README

# Control-M Code Snippets #
[![](https://badgen.net/github/release/controlm/automation-api-community-solutions/stable)]() [![](https://badgen.net/github/tag/controlm/automation-api-community-solutions)]() [![](https://badgen.net/github/status/controlm/automation-api-community-solutions)]() [![](https://badgen.net/github/stars/controlm/automation-api-community-solutions)]() [![](https://badgen.net/github/label-issues/controlm/automation-api-community-solutions/help-wanted/open)]() [![](https://badgen.net/github/commits/controlm/automation-api-community-solutions)]() [![](https://badgen.net/github/releases/controlm/automation-api-community-solutions)]() [![](https://badgen.net/github/license/controlm/automation-api-community-solutions)]() [![](https://badgen.net/github/contributors/controlm/automation-api-community-solutions)]() 

## Overview

This extension enables key features from BMC Software's Control-M product that will allow users to integrate their Workflow Job-As-Code, Git, and Visual Studio Code development processes. Now you can write and debug Control-M Workflow Job-As-Code scripts using the excellent IDE-like interface that Visual Studio Code provides.



## Supported file types or languages

| language    | extension                | description                 |
| ----------- | ------------------------ | --------------------------- |
| JSON        | .json                    | job-as-code script files    |
| Python      | .py                      | job-as-code python files    |


## Features

Describe specific features of your extension including screenshots of your extension in action. Image paths are relative to this README file.

For example if there is an image subfolder under your extension project workspace:

\!\[feature X\]\(images/feature-x.png\)

> Tip: start entering **jac** to get a list of predefined code snippets.

## Install the Control-M Visual Studio Code extension

The Control-M extension can be found in the Visual Studio Code Extension Marketplace. More information on adding extensions to Visual Studio Code can be found [here](https://code.visualstudio.com/docs/introvideos/extend).

As in any Visual Studio Code Extension you have several options to install:

* Enter the Visual Studio Code Marketplace, search for _Control-M Code Snippets_ (or enter directly on [the extension page](https://marketplace.visualstudio.com/items?itemName=bmcsoftware.job-as-code)) and click on _Install_ button.
* Inside Visual Studio Code, enter in the Extensios panel, search for _Control-M Code Snippets_ and click on _Install_ button
* Run the following command in the Command Palette:
	```
	code --install-extension job-as-code-*.vsix
	```

## Platform Support

The extension _should_ work anywhere VS Code itself is [supported]. 

Read the [Start using a Jobs-as-Code approach to build workflows with Control-M](https://controlm.github.io/)
to get more details on how to use the extension on these platforms.

## API Support

Control-M Automation API [Swagger](http://aapi-swagger-doc.s3-website-us-west-2.amazonaws.com/swagger.json) builds the basis of the job-as-code integration and code snippets.

| Name        | description              | 
| ----------- | ------------------------ |
| deploy      | Submit definitions to Control-M. |
| session     | Create and destroy user sessions. |
| archive     | Control-M Archiving operations. |
| build       | Compile definitions to verify they are valid for Control-M. |
| provision   | Install a BigData agent on the current account. |
| reporting   | Generate Control-M reports. |
| run         | Run and track Control-M jobs. |
| config      | Manage Control-M configuration and environment. |

## Usage

TBD


## License

Please see the [BMC License](https://github.com/controlm/automation-api-community-solutions/license.html) file for details on the project.

## Release Notes

### 0.1.*

Initial Alpha Test Version

### 1.0.*
Initial release of the Control-M extension. The extension supports code snippets for Python and JSON Job-As-Code files.

https://code.visualstudio.com/docs/languages/identifiers
