#!/bin/bash 

set +x

print_and_clean_runtime_files() {
    appid=$1
    jobid=$2
    oid=$3
    aws s3 cp s3://623469066856-predictive-maintenance/logs/applications/${appid}/jobs/${jobid}/SPARK_DRIVER/stdout.gz stdout_${oid}.gz
    gunzip stdout_${oid}.gz
    cat stdout_${oid}

    aws s3 cp s3://623469066856-predictive-maintenance/logs/applications/${appid}/jobs/${jobid}/SPARK_DRIVER/stderr.gz stderr_${oid}.gz
    gunzip stderr_${oid}.gz
    cat stderr_${oid}

    aws s3 rm s3://623469066856-predictive-maintenance/maintenance_model_${oid} --recursive
    rm stdout_${oid}
    rm stderr_${oid}    
}

if [ $# -lt 2 ] 
    then 
        echo "First parameter is EMR Serverles Application ID"
        echo "Second parameter is a unique value (Order ID + Runcount is suggested)"
        echo "Third parameter is optional sleep time between polls. Defaults is 10 seconds"
        exit 12
fi

sleeptime=10
appid=${1}
oid=${2}

if [ -n ${3} ]
then
    sleeptime=${3}
fi

echo Parm1 is ${oid} 
echo sleeptime is ${sleeptime}

# Get IAM role of the current ec2 instance to ensure it's authorized to run emr-serverless
#curl --silent http://169.254.169.254/latest/meta-data/iam/info

# Delete output folder in case it already exists
#aws s3 rm s3://623469066856-predictive-maintenance/maintenance_model --recursive

#appid=`aws emr-serverless create-application \
#    --release-label emr-6.10.0 \
#    --type "SPARK" \
#    --name PredictiveMaintenance --query "applicationId" --output text`


jobid=`aws emr-serverless start-job-run \
    --application-id ${appid} \
    --execution-role-arn arn:aws:iam::623469066856:role/EMRServerlessS3RuntimeRole \
    --name jog-pm-spark-analytics \
    --job-driver "{
        \"sparkSubmit\": {
          \"entryPoint\": \"s3://623469066856-predictive-maintenance/lr-assembly-1.0.jar\",
          \"entryPointArguments\": [\"s3://623469066856-predictive-maintenance/maintenance_data.csv\",\"s3://623469066856-predictive-maintenance/maintenance_model_${oid}\"],
          \"sparkSubmitParameters\": \"--class com.bmc.lr.readCSV --conf spark.executor.cores=1 --conf spark.executor.memory=4g --conf spark.driver.cores=1 --conf spark.driver.memory=4g --conf spark.executor.instances=1\"
        }
    }" \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": {
                "logUri": "s3://623469066856-predictive-maintenance/logs/"
            }
        }
    }' \
    --query "jobRunId" --output text`

echo jobid is ${jobid}
echo appid is ${appid}


jobstate="SCHEDULED"
while [ ${jobstate} != "SUCCESS" ]
do
    sleep ${sleeptime}
    jobstate=`aws emr-serverless get-job-run --application-id ${appid} --job-run-id ${jobid} --query "jobRun.state" --output text`
    echo Current job state is $jobstate
    if [ ${jobstate} == "FAILED" ]
    then
        echo Job ${jobid} running on ${appid} failed
        print_and_clean_runtime_files ${appid} ${jobid} ${oid}
        exit 99
    fi
    if [ ${jobstate} == "CANCELLED" ]
    then
        echo Job ${jobid} running on ${appid} cancelled
        print_and_clean_runtime_files ${appid} ${jobid} ${oid}
        exit 32
    fi
done

# Delete application
#aws emr-serverless delete-application \
#    --application-id ${appid}

# Delete output folder in case it already exists
print_and_clean_runtime_files ${appid} ${jobid} ${oid}