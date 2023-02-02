#!/bin/bash
set -ex
python3 runJob.py -j sample-job-001 --image joegoldberg/controlm:appimage --imagepullpolicy Always -e LOOPCTR -v 10 -e STIME -v 5 --imagepullsecret regcred --restartpolicy Never --backofflimit 0

python3 runJob.py -j sample-job-001 --image debian  --commands "printenv"
python3 runJob.py -j sample-job-001 --image debian  --commands "printenv" --args "HOSTNAME KUBERNETES_PORT"

python3 runJob.py -j sample-job-001 --image doesnotexist  --commands "printenv"

python3 runJob.py -j sample-job-001 --image joegoldberg/controlm:appimage --imagepullpolicy Always -e LOOPCTR -v 10 -e STIME -v 5 --imagepullsecret regcred --restartpolicy Never --backofflimit 0 --namespace controlm

python3 runJob.py -y c360srv01-job.yaml             # Namespace in yaml

python3 runJob.py -y c360srv02-job.yaml             # no namespace in yaml

python3 runJob.py -y c360srv02-job.yaml -n controlm # no namespace in yaml, should run in controlm
