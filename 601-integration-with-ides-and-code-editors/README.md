# Integration with IDEs and Code Editors

IDE (Integrated Development Environment) tools and code/text editors can be easily integrated with Control-M Automation API services via command line. This way, a developer could invoke functions such as build, run,
deploy, etc for a json file containing Control-M “Jobs-as-Code” definitions – directly from his tool of choice.

For all the sample integrations shown on this document to work, the Automation API Devkit must be installed on the same computer as the IDE tool or code/text editor, and configured for the required Control-M
endpoint(s). All the examples shown are based on Windows as the operating system.

The integration can also be configured to perform each of these Automation API calls on a Control-M environment of choice. This could be a Control-M environment (Test, Preprod, Production, etc), the Control-
M Workbench or a mix of both – e.g. it could be defined so that the “build” is done against a production environment (to check it validates against its site standards), “run” is done on the Workbench (for local testing),
and “deploy” uses a Preprod environment as the destination (so that jobs are deployed to an intermediate server where the scheduling administrators have the final word to move them onto production). This is
achieved via the “-e” option for the “ctm” commands, e.g. “ctm deploy myfile.json -e preprod”.

When using “ctm run” with the Workbench, the “-i" option can be used so that from the IDE/Editor we also get a popup window (web browser) to interactively monitor the requested workflow, e.g. “ctm run
myfile.json -i -e workbench”.

This folder contains some examples of integration with IDE tools and code/text editors - but this could potentially be achieved with any tool capable of launching external commands from its interface.