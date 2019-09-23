# Control-M Automation API community solutions

>__Note: *We are in the process of updating the folder structure of this repo the better organise the increased amount of contributions. Existing items will move shortly to the new folder structure once we've checked any links to the examples.*__ 

This repository contains solutions, code samples and how-to for Control-M Automation API.  
+ [**Download Workbench for Oracle Virtual Box**](https://s3-us-west-2.amazonaws.com/controlm-appdev/release/v9.18.3/workbench_oracle_virtual_box_ova-9.0.18.300-20190218.133426-1.ova) or [**Download Workbench for VMWare**](https://s3-us-west-2.amazonaws.com/controlm-appdev/release/v9.18.3/workbench_vmware_ova-9.0.18.300-20190218.132300-1.ova) - the latest development Control-M environment Open Virtual Appliance (OVA). 
+ [**Download Automation API CLI**](https://s3-us-west-2.amazonaws.com/controlm-appdev/release/v9.19.130/ctm-cli.tgz) (ctm-cli.tgz).  
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

## Questions/Feedback
Please use issues on GitHub for questions or feedback about the examples included in this repository.
