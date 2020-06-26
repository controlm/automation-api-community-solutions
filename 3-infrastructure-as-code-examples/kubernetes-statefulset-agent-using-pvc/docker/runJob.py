import re

from os import path
from kubernetes import config, client, utils
from kubernetes.utils import FailToCreateError
from kubernetes.client.rest import ApiException
from pprint import pprint

import getopt, os, sys, time
import signal
import yaml

kNameSpace = "default"
kJobname = None
util_client = None
batch_client = None
core_client = None
stime = 3                              # Default sleep interval in seconds for status check in seconds

def get_job_name_from_ymal(yaml_file, verbose=False):
    jobname = None
    with open(path.abspath(yaml_file)) as f:
        yml_document_all = yaml.safe_load_all(f)

        failures = []
        for yml_document in yml_document_all:
            try:
                jobname = get_job_name_from_dict( yml_document, verbose)
            except FailToCreateError as failure:
                failures.extend(failure.api_exceptions)
        if failures:
            raise FailToCreateError(failures)
        return jobname

def get_job_name_from_dict(data, verbose=False):
    # If it is a list type, will need to iterate its items
    api_exceptions = []
    job_name = None
    if "List" in data["kind"]:
        # Could be "List" or "Pod/Service/...List"
        # This is a list type. iterate within its items
        kind = data["kind"].replace("List", "")
        for yml_object in data["items"]:
            # Mitigate cases when server returns a xxxList object
            # See kubernetes-client/python#586
            if kind is not "":
                yml_object["apiVersion"] = data["apiVersion"]
                yml_object["kind"] = kind
            try:
                job_name = get_name_from_yaml_single_item(yml_object, verbose)
            except client.rest.ApiException as api_exception:
                api_exceptions.append(api_exception)
    else:
        # This is a single object. Call the single item method
        try:
            job_name = get_name_from_yaml_single_item(data, verbose)
        except client.rest.ApiException as api_exception:
            api_exceptions.append(api_exception)

    # In case we have exceptions waiting for us, raise them
    if api_exceptions:
        raise FailToCreateError(api_exceptions)

    return job_name

def get_name_from_yaml_single_item(yml_object, verbose=False):
    kind = yml_object["kind"]
    kind = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', kind)
    kind = re.sub('([a-z0-9])([A-Z])', r'\1_\2', kind).lower()
    # Expect the user to create namespaced objects more often
    name = yml_object["metadata"]["name"]
    if verbose:
        msg = "entity {0} name: {1}".format(kind, name)
        print(msg)
    return name

def create_job_object(kJob, kImage, kVname, kVvalue, kimagepullpolicy, kimagepullsecret, krestartpolicy,
                      kbackofflimit, khostpath, kvolname, kvolpath, kpvolclaim, kcommands, kargs):
    # This creates a job object dynamically but supports only limited parameters
	# If you need any characteristics nt supported here, use a yaml manifest 
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
        command=kcommands if len (kcommands) > 0 else None,
        args=kargs if len(kargs) > 0 else None,
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
    api_batch.delete_namespaced_job(kJobname, kNameSpace)
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
    podName = None
    podLabelSelector = 'job-name=' + kJobname
    print("Listing pod for jobname:" + kJobname)
    ret = api_core.list_namespaced_pod(kNameSpace, label_selector=podLabelSelector)
    for i in ret.items:
       podName = str(i.metadata.name)
       print("%s" % i.metadata.name)
    return podName

def startJob(api_util, batch_client, kJobname, yaml):
    try:
       utils.create_from_yaml(api_util, yaml, verbose=True)
    except FailToCreateError as e:
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
          if len(ret.items) <= 0: 
             print ("job was deleted, no info found")
             return (0, 0, 0, 0)

       except:
          print("Failed getting job status: " + kJobname)
          print ("job was deleted, no info found")
          return (0, 0, 0, 0)

       for i in ret.items:
          print("Job status: active %s failed %s succeeded %s\n" % (i.status.active, i.status.failed, i.status.succeeded))
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
    jobStatus = "1" # at least one container failed - job failed
    if podsActive == "None":
       podsActive = "0"
    if podsSucceeded == "None":
       podsSucceeded = "0"
    if podsFailed == "None":
       podsFailed = "0"
       jobStatus = "0" # no contianer failed - job succeeded
    
    return int(jobStatus), podsActive, podsSucceeded, podsFailed

def termSignal(signalNumber, frame):
    #global kJobname, kNameSpace, podName, api_core
    print("Terminating due to SIGTERM: " + signalNumber)
    podName = listPod(core_client, kJobname)
    getLog(core_client, podName)
    deleteJob(batch_client, kJobname, podName)
    sys.exit(8)

def usage():
    print("\n\tjobname is the only mandatory parameter. If yaml manifest specified, all other options ignored.\n")
    print("\t-a, --args\t\targuaments (default None, container args will be used)")
    print("\t-b, --backofflimit\tdefault is 0")
    print("\t-c, --claim\t\tname of persistent volume claim")
    print("\t-e, --envname\t\tEnvironment variable name")
    print("\t-H, --hostpath\t\tPath on host machine (must be a directory)")
    print("\t-i, --image\t\tcontainer image name")
    print("\t-j, --jobname\t\tMandatory. Job name")
    print("\t-m, --volname\t\tVolume mount name")
    print("\t-k, --command\t\tcommand to run (default None, continer entrypoint will be used)")
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
    kvolname, kvolpath, kpvolclaim, kcommands, kargs):

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
          "\tCommands: %s \n"
          "\tArgs: %s \n"
          "\tYaml file: %s \n"
          % (kJobname, kVname,
             kVvalue, kImagename, kimagepullpolicy,
             kimagepullsecret, krestartpolicy,
             kbackofflimit, kvolname, khostpath,
             kvolpath, kpvolclaim, kcommands, kargs, kYaml))

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
    kcommands = []
    kargs = []

    # Arguments:
    #   a|args              arguments to pass to -k|Commands (default is None) 
    #   b|backofflimit      default is 0
    #   c|claim             PersistentVolumeClaim
    #   e|envname           environment variable name
    #   H|hostpath          Path on host machine (must be a directory}
    #   i|image             container image name
    #   j|jobname           Mandatory. Job name
    #   m|volname           Volume mount name
    #   m|commands          Commands to run in container (entrypoint)
    #   p|image_pull_policy Always or Latest
    #   r|restartpolicy     default is Never
    #   s|imagesecret       name of image_pull_secret
    #   t|volpath           Volume mount path in Pod
    #   v|envvalue          variable value
    #   y|yaml              name of a yaml manifest for job creation. Overrides all others except jobname
    #
    try:
       opts, args = getopt.getopt(argv,"hj:c:i:e:v:y:p:s:r:b:H:m:t:a:k:",
                                  ["jobname=","claim=", "image=","envname=","envvalue=","yaml=","imagepullpolicy=",
                                   "imagepullsecret=", "restartpolicy=", "backofflimit=", "hostpath=",
                                   "volname=", "volpath=","commands=","args="])
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
       elif opt in ("-k", "--commands"):
          kcommands.append(arg)
       elif opt in ("-a", "--args"):
          kargs.append(arg)

    used_opts(kJobname, kYaml, kVname,
              kVvalue, kImagename, kimagepullpolicy,
              kimagepullsecret, krestartpolicy,
              kbackofflimit, khostpath,
              kvolname, kvolpath,kpvolclaim, kcommands, kargs)

    if kJobname == '' and kYaml == '':
       usage()
       sys.exit(2)
    elif kJobname == '' and kYaml != '':
       kJobname = get_job_name_from_ymal(kYaml)
    elif kJobname != '' and kYaml != '':
       ymlJobName = get_job_name_from_ymal(kYaml)
       if (ymlJobName != kJobname):
         print ("jobname -j '%s' not equal to the jobname in the yaml file '%s'" % (kJobname, ymlJobName))
         sys.exit(26)

    #config.load_kube_config()
    clientConf = client.Configuration()
    # assuming the script is running in pod: 
    # token in: /var/run/secrets/kubernetes.io/serviceaccount/token
    # ca in: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    # api server: https://kubernetes.default
    # (true for all pods)
    with open('/var/run/secrets/kubernetes.io/serviceaccount/token') as f:
      token = f.read()
    clientConf.host = 'https://kubernetes.default'  
    clientConf.api_key['authorization'] = token
    clientConf.api_key_prefix['authorization'] = 'Bearer'
    clientConf.ssl_ca_cert = '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
    # can also use the default in-cluster way
    #ApiClient client = ClientBuilder.cluster().build();

    util_client = client.ApiClient(clientConf)
    batch_client = client.BatchV1Api(util_client)
    core_client = client.CoreV1Api(util_client)
    job_exist = False

    try:
      podName = listPod(core_client, kJobname)
      # There can't be more than 1 deployment (kube job) with the same name
      # do we want to delete ?
      job_exist =  podName is not None 
    except ApiException as e:
      print("Exception when calling BatchV1Api->read_namespaced_job_status: %s\n" % e)
      sys.exit(16)


    if not job_exist:
      print "job not exist - creating (starting) job"
      if kYaml != '':
         print("Yaml specified. All other arguments - besides jobname - ignored")
         startJob(util_client, batch_client, kJobname, kYaml)
      else:
         job = create_job_object(kJobname, kImagename, kVname, kVvalue, kimagepullpolicy, kimagepullsecret,
                                 krestartpolicy, kbackofflimit, khostpath, kvolname, kvolpath, kpvolclaim, kcommands, kargs)
         try:
            createJob(batch_client, job)
         except:
            print("Job creation failed")
            sys.exit(16)
    else: 
      print "job already exist - start monitoring"

    #signal.signal(signal.SIGTERM, termSignal)
    jobStatus, podsActive, podsSucceeded, podsFailed = status(batch_client, kJobname)

    
    if (podName is None):
      # incase the job started (initial list returned none since the job didnt exist)
      podName = listPod(core_client, kJobname)
    
    getLog(core_client, podName)

    print("Pods Statuses: %s Running / %s Succeeded / %s Failed" % (podsActive, podsSucceeded, podsFailed))
    print("Job Completion status: %d " % (jobStatus))
   
    deleteJob(batch_client, core_client, kJobname, podName)
   
    sys.exit(jobStatus)

if __name__ == '__main__':
    main(sys.argv[1:])
