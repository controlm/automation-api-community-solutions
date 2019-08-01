pipeline {
    agent any
    stages {
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
        stage('Test') {
            when {
            expression {
                return env.BRANCH_NAME != 'master';
                }
            }
            environment {
                CONTROLM_CREDS = credentials('controlm-testserver-creds')
                ENDPOINT = 'https://clm-aus-tobcvy:8446/automation-api'
            }
            steps {
                sh '''
                # execute all .sh scripts in the tests directory
                cd ./tests/
                for f in *.sh
                do
                    bash "$f" -H || exit $?  # execute successfully or exit
                done
                cd ..
                '''
            }
        }
        stage('Deploy') {
            when{
                branch 'master'
            }
            environment {
                CONTROLM_CREDS = credentials('controlm-prodserver-creds')
                ENDPOINT = 'https://clm-aus-tobcvy:8446/automation-api'
            }
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
        }
    }
}
