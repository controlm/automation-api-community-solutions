# 2. Automating testing and deployment

## 2a. Connect Jenkins to your git repo

We won't cover that here as there are many other resources that cover this in
detail.

## 2b. Create a file named Jenkinsfile

The Jenkinsfile defines the pipeline that Jenkins will use to build, test, and 
deploy our jobs.

The general structure of this file is:
```
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                echo Build Step
            }
        }
        stage('Test') {
            steps {
                echo Test Step
            }
        }
        stage('Deploy') {
            steps {
                echo Deploy Step
            }
        }
    }
}

```

## 2c. Build Step

The build step ensures that structure of the Control-M Automation API json files
are valid.

To do this, we utilize the ```$endpoint/build``` service provided by Automation 
API in the build step:

```
<snip>
        stage('Build') {
            environment {
                CONTROLM_CREDS = credentials('controlm-testserver-creds')
                ENDPOINT = 'https://clm-aus-tobcvy:8446/automation-api'
            }
            steps {
                sh '''
                username=$CONTROLM_CREDS_USR
                password=$CONTROLM_CREDS_PSW

                # Login
                login=$(curl -k -s -H "Content-Type: application/json" -X POST -d \\{\\"username\\":\\"$username\\",\\"password\\":\\"$password\\"\\} "$ENDPOINT/session/login" )
                token=$(echo ${login##*token\\" : \\"} | cut -d '"' -f 1)

                # Build
                curl -k -s -H "Authorization: Bearer $token" -X POST -F "definitionsFile=@ctmjobs/MFT-conn-profiles.json" "$ENDPOINT/build"
                curl -k -s -H "Authorization: Bearer $token" -X POST -F "definitionsFile=@ctmjobs/jobs.json" "$ENDPOINT/build"
                curl -k -s -H "Authorization: Bearer $token" -X POST "$ENDPOINT/session/logout"
                '''
            }
        }
<snip>
```

Credentials are stored in Jenkins and configured/administered there, so they
do not have to be included in plaintext in the scripts. The `credentials()` 
function sets enviroment variables for use in the script and Jenkins will 
automatically mask the usernames and passwords in any output generated.

Note that additional escaping of double quotes and backslashes is required when 
running shell commands in a Jenkins pipeline.

## 2d. Test Step

The test step verifies that the Jobs run as intended in Control-M.

This step should only be run for branches other than master because we don't
want to run tests in the production environment. To accomplish this the 
following code is added to the Test stage of the Jenkinsfile:

```
<snip>
        stage('Test') {
            when {
            expression {
                return env.BRANCH_NAME != 'master';
                }
            }
            steps {
<snip>
```

The tests created by the developer(s) are kept in the ./tests/ directory, and
named `*.sh`. The Jenkinsfile Test code therefore loops through those files and 
executes them each in order.

```
<snip>
            steps {
                sh '''
                # execute all .sh scripts in the tests directory
                cd ./tests/
                for f in *.sh
                do
                    bash "$f" -H || break  # execute successfully or break
                done
                cd ..
                '''
            }
<snip>
```

An example test script is provided here: [001-run-jobs.sh](./tests/001-run-jobs.sh)

To perform the test, the jobs are run using the ```$endpoint/run``` service of 
Automating API and the status is periodically checked using the 
```$endpoint/run/status/$runid``` request. See the below snippet of the test s
teps for a basic test to ensure that no jobs End Not OK.


## 2e. Deploy to Production

After the changes made by a developer in a new branch passes the tests in the 
pipeline, a merge request can be opened to request that the changes be added to 
the master branch and pushed to production.

**Note**: Opening and aproving can be configured to be an automatic process 
dependent on passing the checks in the CI/CD pipeline, or the process can be 
manually approved after the changes have been reviewed by a maintainer on the 
git repository. This can be configured to meet your organizational requirements.

To ensure that only code that has been merged into the master branch is deployed
into the production environment, the following is added to the Deploy stage in 
the Jenkinsfile:

```
<snip>
        stage('Deploy') {
            when{
                branch 'master'
            }
            steps {
<snip>
```

The production ready code is deployed using the ```$endpoint/deploy``` Automation
API request in the below snippet of the Deploy steps from the Jenkinsfile:

```
<snip>
            steps {
                sh '''
                username=$CONTROLM_CREDS_USR
                password=$CONTROLM_CREDS_PSW

                # Login
                login=$(curl -k -s -H "Content-Type: application/json" -X POST -d \\{\\"username\\":\\"$username\\",\\"password\\":\\"$password\\"\\} "$ENDPOINT/session/login" )
                token=$(echo ${login##*token\\" : \\"} | cut -d '"' -f 1)

                # Deploy connection profiles and jobs
                curl -k -s -H "Authorization: Bearer $token" -X POST -F "definitionsFile=@ctmjobs/MFT-conn-profiles.json" "$ENDPOINT/deploy"
                curl -k -s -H "Authorization: Bearer $token" -X POST -F "definitionsFile=@ctmjobs/jobs.json" "$ENDPOINT/deploy"
                curl -k -s -H "Authorization: Bearer $token" -X POST "$ENDPOINT/session/logout"
                '''                
            }
<snip>
```