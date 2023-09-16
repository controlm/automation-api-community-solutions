from ctm_python_client.core.workflow import Workflow, WorkflowDefaults
from ctm_python_client.core.comm import Environment
from ctm_python_client.core.credential import *
from aapi import *

# Define environment and workflow defaults
workflow = Workflow(
    Environment.create_saas('https://example.ctmdemo.com:8443/automation-api', api_key='your-api-key'),
    WorkflowDefaults(
        host="your-agent-host",
        application= "mol-python-client",
        sub_application="glue-demo",
        run_as="your-agent-user"
    )
)

# Creating two simple OS jobs
firstjob = JobCommand('MyFirstJob', 
    command='echo "Hello world!"',
    host="your-agent-host",
    run_as="your-agent-user"
)

secondjob = JobCommand('MySecondJob', 
    command='echo "Hello again!"',
    host="your-agent-host",
    run_as="your-agent-user"
)

# Create an AWS Glue job
my_glue_job = JobAwsGlue('JobAWSGlueSample',
    connection_profile = "your-connection-profile",
    glue_job_name="your-glue-job-name"
)

# Adding jobs to a Folder
my_folder = Folder('MyFolder', job_list=[firstjob, secondjob, my_glue_job])

# Add the Folder to the Workflow and deploy it
workflow.add(my_folder)
workflow.connect('MyFolder/MyFirstJob', 'MyFolder/MySecondJob')
workflow.connect('MyFolder/MySecondJob', 'MyFolder/JobAWSGlueSample')

# Deploying the workflow
if workflow.build().is_ok():
    print('The workflow is valid!')
if workflow.deploy().is_ok():
    print('The workflow was deployed to Control-M!')


# Assuming `workflow` is your deployed Workflow object
run = workflow.run()

# Fetch and print the job outputs
run.print_output('MyFolder/MyFirstJob')
run.print_output('MyFolder/MySecondJob')
run.print_output('MyFolder/JobAWSGlueSample')
