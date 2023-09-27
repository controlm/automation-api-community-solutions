from ctm_python_client.core.workflow import *
from ctm_python_client.core.comm import Environment
from ctm_python_client.core.monitoring import *
from aapi import *
import json

# Define environment and workflow defaults (replace with your values)
ctm_workflow = Workflow(
        Environment.create_saas("https://<Your-ControlM-Host>:<Port>/automation-api", api_key="<Your-API-Key>"),
    WorkflowDefaults(
        controlm_server="<Your-ControlM-Server>",
        application="<Your-Application>",
        host= "<Your-Host>",
        run_as="<Your-RunAs>"
    )
)

# Define AWS Glue Connection Profile (replace with your values)
cp = ConnectionProfileAwsGlue('<Your-Connection-Profile-Name>',
    centralized=True,
    aws_region="<AWS-Region>",
    authentication='<Authentication-Type>',
    aws_access_key_id   = "<Your-AWS-Access-Key-ID>",
    aws_secret          = "<Your-AWS-Secret>",
    glue_url='<Your-Glue-URL>',
    connection_timeout='<Timeout>'
)

# Add connection profile to workflow and deploy it to Control-M
ctm_workflow.add(cp)
cp_results = ctm_workflow.deploy(cp)

# Check deployment status
if cp_results.is_ok():
    print('The workflow was deployed to Control-M!')
    # Clear all objects from the workflow to avoid duplication
    ctm_workflow.clear_all()
else:
    print("Error deploying Connection Profile")
    print(ctm_workflow.dumps_json(indent=2))
    exit()
