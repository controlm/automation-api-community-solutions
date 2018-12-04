# Integration with IDEs and Code Editors

IDE (Integrated Development Environment) tools and code/text editors can be easily integrated with [Control-M Automation API Services](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Services) via command line. This way, a developer can invoke services such as *build*, *run*, *deploy*, etc for a JSON file containing Control-M "Jobs-as-Code" definitions – directly from his tool of choice.

This folder contains some examples of integrations with IDE tools and code/text editors. The same functionality can be achieved with any tool capable of launching external commands from its graphical interface.

For any of these sample integrations to work, the **Control-M Automation Command Line Interface (CLI)** must be installed on the same computer as the IDE tool or code/text editor, and configured for the required Control-M endpoint(s). For more details, please check the [Control-M Automation API Installation](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Installation) documentation and look for "*Installing the Control-M Automation CLI*".


Optional:

The integration can also be configured to perform each of these Automation API calls on a Control-M environment of choice. This could be a Control-M environment (Test, Preprod, Production, etc), the Control-M Workbench or a mix of both – e.g. it could be defined so that the “build” is done against a production environment (to check it validates against its site standards), “run” is done on the Workbench (for local testing), and “deploy” uses a Preprod environment as the destination (so that jobs are deployed to an intermediate server where the scheduling administrators have the final word to move them onto production). This is achieved via the “-e” option for the “ctm” commands, e.g. “ctm deploy myfile.json -e preprod”.
