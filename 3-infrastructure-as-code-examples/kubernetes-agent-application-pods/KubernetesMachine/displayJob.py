from os import path
from kubernetes import config, client, utils
from kubernetes.client.rest import ApiException
from pprint import pprint

import getopt, os, sys, time
import signal
import yaml

kNameSpace = "default"

def showjob(batch_client, kJobname):

    try:
        api_response = batch_client.read_namespaced_job(kJobname, kNameSpace)
        pprint(api_response)
    except ApiException as e:
        print("Exception when calling BatchV1Api->read_namespaced_job: %s\n" % e)
        sys.exit(2)

    print("Job {0} created".format(kJob.metadata.name))
    return


def main(argv):
    kJobname = ''
    kYaml = ''
    optnum = 0

    # Arguments:
    #   e|envname - environment variable name
    #   i|image - container image name
    #   j|jobname - Mandatory. Job name. If specified on its n=own, the name of a YAML manifest <jobname>-job.yaml
    #   v|value - variable value
    #   y|yaml - name of a yaml manifest to use for job creation
    #
    #   If y|yaml is secified, all other optional parameters are ignored. If only j|jobname specified, job is created from
    #   a yaml file named <jobname>-job.yaml.
    try:
        kVname = []
        kVvalue = []
        opts, args = getopt.getopt(argv, "hj:", ["jobname="])
    except getopt.GetoptError:
        print(
            "runjob.py -j <jobname> [-i <container image name> -e <environment variable name> -v <environment variable value> -y <yaml file>]")
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print(
                "runjob.py -j <jobname> [-i <container image name> -e <environment variable name> -v <environment variable value> -y <yaml file>]")
            sys.exit()
        elif opt in ("-j", "--jobname"):
            kJobname = arg

    if kJobname == '':
        print(
            "runjob.py -j <jobname> [-i <container image name> -e <environment variable name> -v <environment variable value> -y <yaml file>]")
        sys.exit(2)

    print("Jobname: %s Yaml: %s Imagename: %s #Vars: %i #Vals: %i" % (kJobname, kYaml, kImagename, len(kVname), len(kVvalue)))

    config.load_kube_config()
    batch_client = client.BatchV1Api()
    showjob(batch_client. kJobname)

    sys.exit(jobStatus)

if __name__ == '__main__':
    main(sys.argv[1:])

