# Control-M Automation API community solutions

This repository contains solutions, code samples and how-to for Control-M Automation API.  
+ [**Download Workbench**](https://s3-us-west-2.amazonaws.com/controlm-appdev/release/v5/workbench_ova-9.0.00.500-20171107.170253-28.ova) latest development Control-M environment Open Virtual Appliance (OVA).  
+ [**Download Automation API CLI**](https://s3-us-west-2.amazonaws.com/controlm-appdev/release/v5/ctm-cli.tgz) (ctm-cli.tgz).  
+ [**Installation instructions**](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Installation).  

## Online Documentation
You can find the latest Control-M Automation API documentation, including a programming guide, on the [**project web page**](https://docs.bmc.com/docs/display/public/workloadautomation/Control-M+Automation+API+-+Getting+Started+Guide).

## Contribution guide
To contribute, please follow these guidelines.

### Files, folders and naming conventions
1. Every sample and its associated files must be contained in its own **folder**. Name this folder something that describes what your sample does. Usually this naming pattern looks like **level-sample-purpose** (e.g. 201-automate-corrective-flow). Numbering should start at 101. 100 is reserved for things that need to be at the top.

      For consistent categorization, please comply to the following folder structure:
      + 1xx General Automation API usage examples
      + 2xx CI/CD tooling integration
      + 3xx infrastructure-as-code examples
      + 4xx AI job type examples
      + 5xx Bots / Dashboard examples
      + 6xx IDE integrations

2. For consistent ordering **create all folders in lowercase**.
3. Include a **README.md** file that explains the sample. A good description helps other community members to understand your sample. The README.md uses [Github Flavored Markdown](https://guides.github.com/features/mastering-markdown/) for formatting text. If you want to add images to your README.md file, store the images in the **images** folder. Reference the images in the README.md with a relative path (e.g. `![alt text](images/sampleImage.png "Sample Image Text")`). This ensures the link will reference the target repository if the source repository is forked.
