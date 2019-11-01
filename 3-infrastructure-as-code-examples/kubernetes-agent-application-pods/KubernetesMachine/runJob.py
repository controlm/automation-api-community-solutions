
from os import path
from kubernetes import config, client, utils
from kubernetes.client.rest import ApiException
from pprint import pprint

import getopt, os, sys, time
import signal
import yaml

kNameSpace = "default"
stime = 15                              # Default sleep interval in seconds for status check

def create_job_object(kJob, kImage, kVname, kVvalue, kimagepullpolicy, kimagepullsecret, krestartpolicy, kbackofflimit, khostpath, kvolname, kvolpath, kpvolclaim):
    # This creates a job object dynamically but supports only limited parameters
	# Ifyou need any characteristics nt supported here, use a yaml manifest 
    #  
	
    # Configure environment variables
    env_list = []
    for key in kVname:
        value = kVvalue[kVname.index(key)]
        v1_envvar = client.V1EnvVar(name=key, value=value)
        env_list.append(v1_envvar)

    # Configure Volume Devices and Mounts
    volnames_list = []
    if kvolname != 'none':
       volname = client.V1VolumeMount(
          name=kvolname,
          mount_path=kvolpath)
       volnames_list.append(volname)

    # Configure Volumes list
    vol_list = []
    if kvolname != 'none':
       if kpvolclaim != 'none':
           vol = client.V1Volume(name=kvolname,
                                 persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                                     claim_name=kpvolclaim))
       else:
           vol = client.V1Volume(name=kvolname,
                             host_path=client.V1HostPathVolumeSource(path=khostpath,
                                                                     type='Directory'))
       vol_list.append(vol)

    # Configure Pod template container
    container = client.V1Container(  
        name="ctmjob", 
        image=kImage,
        image_pull_policy=kimagepullpolicy,
        env=env_list,
        volume_mounts=volnames_list)

    # Configure Image Pull Secret(s)
    imagesecrets = []
    isecret = client.V1LocalObjectReference(name=kimagepullsecret)
    imagesecrets.append(isecret)

    # Create and configure a spec section
    template = client.V1PodTemplateSpec(
        metadata=client.V1ObjectMeta(name=kJob),
        spec=client.V1PodSpec(containers=[container],
                              image_pull_secrets=imagesecrets,
                              restart_policy=krestartpolicy,
                              volumes=vol_list))

    # Create the specification of deployment
    spec = client.V1JobSpec(
        template=template,
        backoff_limit=kbackofflimit)

    # Instantiate the job object
    job = client.V1Job(
        api_version="batch/v1",
        kind="Job",
        metadata=client.V1ObjectMeta(name=kJob),
        spec=spec)

    return job
	
def createJob(api_batch, job):
    try:
       api_response = api_batch.create_namespaced_job(body=job, namespace="default")
       print("Job created. status='%s'" % str(api_response.status))
    except ApiException as e:
       print("Exception when calling BatchV1Api->create_namespaced_job: %s\n" % e)
       pprint(job)
       sys.exit(3)

def deleteJob(api_batch, api_core, kJobname, podName):
    ret = api_batch.delete_namespaced_job(kJobname, kNameSpace)
    print("Job deleted: " + kJobname)
   
#   podBody = client.V1DeleteOptions()
    ret = api_core.delete_namespaced_pod(podName, kNameSpace)
    print("Pod deleted: " + podName)

def getLog(api_core, podName):
    ret = api_core.read_namespaced_pod_log(podName, kNameSpace)
    print("Log output from Pod: " + podName)
    print(ret)
    return

def listPod(api_core, kJobname):
    podLabelSelector = 'job-name=' + kJobname
    print("Listing pod for jobname:" + kJobname)
    ret = api_core.list_namespaced_pod(kNameSpace, label_selector=podLabelSelector)
    for i in ret.items:
       podName = str(i.metadata.name)
       print("%s" % i.metadata.name)
    return podName

def startJob(api_util, batch_client, kJobname, yaml):
    try:
       api_response = utils.create_from_yaml(api_util, yaml)
    except Apiexception as e:
       print("Exception when calling UtilAPI->create_from_yaml: %s\n" % e)
       sys.exit(5)

    try:
       api_response = batch_client.read_namespaced_job(kJobname, kNameSpace)
       pprint(api_response)
    except ApiException as e:
       print("Exception when calling BatchV1Api->read_namespaced_job: %s\n" % e)
       sys.exit(6)

    print("Job {0} created".format(api_response.metadata.name))
    return
   
def status(api_batch, kJobname):
    print("Starting to track job status for: %s\n" % kJobname)
    jobStatus = "Success"
    jobRunning = "Running"
    podLabelSelector = 'job-name=' + kJobname
    time.sleep(stime)                  # Give the Pod a chance to initialize

    while jobRunning == "Running":
       try:
          ret = api_batch.list_namespaced_job(kNameSpace, label_selector=podLabelSelector)
       except:
          print("Failed getting job status: " + kJobname)
          sys.exit(4)

       for i in ret.items:
          print("Status active %s failed %s succeeded %s\n" % (i.status.active, i.status.failed, i.status.succeeded))
          jobStatus = str(i.status.active)
          podsFailed = str(i.status.failed)
          podsSucceeded = str(i.status.succeeded)
          if jobStatus.isdigit():
             if jobStatus >= "1":
                jobRunning = "Running"
                time.sleep(stime)
             else:
                jobRunning = "Not Running"
          else:
             jobRunning = "Not Running"

    podsFailed = str(i.status.failed)
    podsSucceeded = str(i.status.succeeded)
    podsActive = str(i.status.active)
    if podsActive == "None":
       podsActive = "0"
    if podsSucceeded == "None":
       podsSucceeded = "0"
    if podsFailed == "None":
       podsFailed = "0"
    if podsSucceeded >= 1:
       jobStatus = "0"
    else:
       jobStatus = "1"
    
    return int(jobStatus), podsActive, podsSucceeded, podsFailed

def termSignal(signalNumber, frame):
    global kJobname, kNameSpace, podName
    print("Terminating due to SIGTERM: " + signalNumber)
    podName = listPod(kJobname)
    getLog(podName)
    deleteJob(kJobname, podName)
    sys.exit(8)

def usage():
    print("\n\tjobname is the only mandatory parameter. If yaml manifest specified, all other options ignored.\n")
    print("\t-b, --backofflimit\tdefault is 0")
    print("\t-c, --claim\t\tname of persistent volume claim")
    print("\t-e, --envname\t\tEnvironment variable name")
    print("\t-H, --hostpath\t\tPath on host machine (must be a directory)")
    print("\t-i, --image\t\tcontainer image name")
    print("\t-j, --jobname\t\tMandatory. Job name")
    print("\t-m, --volname\t\tVolume mount name")
    print("\t-p, --image\t\tpull_policy Always or Latest")
    print("\t-r, --restartpolicy\tefault is Never")
    print("\t-s, --imagesecret\ttname of image_pull_secret")
    print("\t-t, --volpath\t\tVolume mount path in Pod")
    print("\t-v, --envvalue\t\tvariable value")
    print("\t-y, --yaml\t\tname of a yaml manifest for job creation. Overrides all others except jobname")

def used_opts(kJobname, kYaml, kVname,
    kVvalue, kImagename, kimagepullpolicy,
    kimagepullsecret, krestartpolicy,
    kbackofflimit, khostpath,
    kvolname, kvolpath, kpvolclaim):

    print("Command line options specified:")
    print("\tjobname: %s \n"
          "\tEnvironment Variables: %s \n"
          "\tEnvironment Values: %s \n"
          "\tContainer image: %s \n"
          "\tImage_pull_policyy: %s \n"
          "\tImage_pull_secret: %s \n"
          "\tRestart_policy: %s \n"
          "\tbackofflimit: %d \n"
          "\tVolume Name: %s \n"
          "\tHost path: %s \n"
          "\tContainer Path: %s \n" 
          "\tPersistentVolumeClaim: %s \n"
          "\tYaml file: %s \n"
          % (kJobname, kVname,
             kVvalue, kImagename, kimagepullpolicy,
             kimagepullsecret, krestartpolicy,
             kbackofflimit, kvolname, khostpath,
             kvolpath, kpvolclaim, kYaml))

def main(argv):
    kJobname = ''
    kYaml = ''
    kVname = []
    kVvalue = []
    kImagename = 'none'
    kpvolclaim = 'none'
    kimagepullpolicy = 'Always'
    kimagepullsecret = 'regcred'
    krestartpolicy = 'Never'
    kbackofflimit = 0
    khostpath = 'none'
    kvolname = 'none'
    kvolpath = 'none'

    # Arguments:
    #   b|backofflimit      default is 0
    #   c|claim             PersistentVolumeClaim
    #   e|envname           environment variable name
    #   H|hostpath          Path on host machine (must be a directory}
    #   i|image             container image name
    #   j|jobname           Mandatory. Job name
    #   m|volname           Volume mount name
    #   p|image_pull_policy Always or Latest
    #   r|restartpolicy     default is Never
    #   s|imagesecret       name of image_pull_secret
    #   t|volpath           Volume mount path in Pod
    #   v|envvalue          variable value
    #   y|yaml              name of a yaml manifest for job creation. Overrides all others except jobname
    #
    try:
       opts, args = getopt.getopt(argv,"hj:c:i:e:v:y:p:s:r:b:H:m:t:",
                                  ["jobname=","claim=", "image=","envname=","envvalue=","yaml=","imagepullpolicy=",
                                   "imagepullsecret=", "restartpolicy=", "backofflimit=", "hostpath=",
                                   "volname=", "volpath="])
    except getopt.GetoptError:
       usage()
       sys.exit(1)

    for opt, arg in opts:
       if opt == '-h':
          usage()
          sys.exit(0)
       elif opt in ("-e", "--envname"):
          kVname.append(arg)
       elif opt in ("-c", "--claim"):
          kpvolclaim = arg
       elif opt in ("-i", "--image"):
          kImagename = arg
       elif opt in ("-j", "--jobname"):
          kJobname = arg
       elif opt in ("-v", "--envvalue"):
          kVvalue.append(arg)
       elif opt in ("-y", "--yaml"):
          kYaml = arg
       elif opt in ("-b", "--backofflimit"):
          kbackofflimit = int(arg)
       elif opt in ("-p", "--imagepullpolicy"):
          kimagepullpolicy = arg
       elif opt in ("-r", "--restartpolicy"):
          krestartpolicy = arg
       elif opt in ("-s", "--imagepullsecret"):
          kimagepullsecret = arg
       elif opt in ("-H", "--hostpath"):
          khostpath = arg
       elif opt in ("-m", "--volname"):
          kvolname = arg
       elif opt in ("-t", "--volpath"):
          kvolpath = arg

    used_opts(kJobname, kYaml, kVname,
              kVvalue, kImagename, kimagepullpolicy,
              kimagepullsecret, krestartpolicy,
              kbackofflimit, khostpath,
              kvolname, kvolpath,kpvolclaim)

    if kJobname == '':
       usage()
       sys.exit(2)

    config.load_kube_config()
    util_client = client.ApiClient()
    batch_client = client.BatchV1Api()
    core_client = client.CoreV1Api()
   
    if kYaml != '':
       print("Yaml specified. All other arguments - besides jobname - ignored")
       startJob(util_client, batch_client, kJobname, kYaml)
    else:
       job = create_job_object(kJobname, kImagename, kVname, kVvalue, kimagepullpolicy, kimagepullsecret, krestartpolicy, kbackofflimit, khostpath, kvolname, kvolpath, kpvolclaim)
       try:
           createJob(batch_client, job)
       except:
           print("Job creation failed")
           sys.exit(16)

    signal.signal(signal.SIGTERM, termSignal)
    jobStatus, podsActive, podsSucceeded, podsFailed = status(batch_client, kJobname)

    podName = listPod(core_client, kJobname)
    getLog(core_client, podName)

    print("Pods Statuses: %s Running / %s Succeeded / %s Failed" % (podsActive, podsSucceeded, podsFailed))
    print("Job Completion status: %d " % (jobStatus))
   
    deleteJob(batch_client, core_client, kJobname, podName)
   
    sys.exit(jobStatus)
   
if __name__ == '__main__':
    main(sys.argv[1:])