
from os import path
from kubernetes import config, client, utils, watch
from kubernetes.client.rest import ApiException
from pprint import pprint

import getopt, os, sys, time
import signal
import yaml

kNameSpace = ""                         # Expect Namespace to come from parameter or manifest
stime = 15                              # Default sleep interval in seconds for status check

def create_job_object(kJob, kImage, kVname, kVvalue, kimagepullpolicy, kimagepullsecret, krestartpolicy,
                      kbackofflimit, khostpath, kvolname, kvolpath, kpvolclaim):
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
       api_response = api_batch.create_namespaced_job(body=job, namespace=kNameSpace)
       print("Job created. status='%s'" % str(api_response.status))
    except ApiException as e:
       print("Exception when calling BatchV1Api->create_namespaced_job: %s\n" % e)
       pprint(job)
       sys.exit(3)

def deleteJob(api_batch, api_core, kJobname, podName):
    api_response = api_batch.delete_namespaced_job(kJobname, kNameSpace)
    print("\nJob %s deleted: status='%s'" % (kJobname, str(api_response.status)))

    api_response = api_core.delete_namespaced_pod(podName, kNameSpace)
    print("\nPod %s deleted: status='%s'" % (podName, str(api_response.status)))

    return

def getLog(api_core, podName):
    print("Log output from Pod: " + podName)
    w = watch.Watch()
    for logentry in w.stream(api_core.read_namespaced_pod_log, name=podName, namespace=kNameSpace, follow=True):
       print(logentry)
    print("Log output completed ")

    return

def listPod(api_core, kJobname):
    global podName
    podLabelSelector = 'job-name=' + kJobname
    print("Listing pod for jobname:" + kJobname)
    try: 
       ret = api_core.list_namespaced_pod(kNameSpace, label_selector=podLabelSelector)
    except ApiException as e:
       print("Exception listing pods for job %s namespace %s error: %s\n" % (kJobname, kNameSpace, e))
       sys.exit(6)
   
    for i in ret.items:
       podName = str(i.metadata.name)
       print("%s" % i.metadata.name)
    return podName

def startJob(api_util, batch_client, kJobname, yaml):
    verbose = False
    try:
       api_response = utils.create_from_yaml(api_util, yaml, verbose, namespace=kNameSpace)
    except ApiException as e:
       print("Exception when calling UtilAPI->create_from_yaml: %s\n" % e)
       sys.exit(5)

    try:
       api_response = batch_client.read_namespaced_job(kJobname, kNameSpace)
#      pprint(api_response)
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
                            # Give the job time to warm up

    getLog(core_client, podName)                # Stream the log output

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
    if podsSucceeded.isdigit():
       if int(podsSucceeded) >= 1:
          jobStatus = "0"
       else:
          jobStatus = "1"
    
    return int(jobStatus), podsActive, podsSucceeded, podsFailed

def termSignal(signalNumber, frame):
    global podName
    print("Terminating due to SIGTERM: " + signalNumber)
    podName = listPod(core_client, kJobname)
    getLog(core_client, podName)
    deleteJob(batch_client, core_client, kJobname, podName)
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
    print("\t-n, --namespace\t\tKubernetes Name Space")
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

    print("Execution options specified:")
    print("\tjobname: \t\t\t%s \n"
          "\tEnvironment Variables: \t\t%s \n"
          "\tEnvironment Values: \t\t%s \n"
          "\tContainer image: \t\t%s \n"
          "\tImage_pull_policyy: \t\t%s \n"
          "\tImage_pull_secret: \t\t%s \n"
          "\tRestart_policy: \t\t%s \n"
          "\tbackofflimit: \t\t\t%d \n"
          "\tVolume Name: \t\t\t%s \n"
          "\tHost path: \t\t\t%s \n"
          "\tContainer Path: \t\t%s \n" 
          "\tPersistentVolumeClaim: \t\t%s \n"
          "\tYaml file: \t\t\t%s \n"
          "\tName Space: \t\t\t%s \n"
          % (kJobname, kVname, kVvalue, kImagename, kimagepullpolicy,
             kimagepullsecret, krestartpolicy, kbackofflimit, kvolname, khostpath,
             kvolpath, kpvolclaim, kYaml, kNameSpace))

def yamlload(kYaml):
    manifest = open(kYaml)
    ynamespace = kNameSpace
    yjobname = kJobname
    yamldata = yaml.load(manifest, Loader=yaml.FullLoader)
    if 'metadata' in yamldata:
       metadata = yamldata.get('metadata')
       if 'namespace' in metadata:
          ynamespace = metadata.get('namespace')
       if 'name' in metadata:
          yjobname = metadata.get('name')
          
    return ynamespace, yjobname

def main(argv):

    global kNameSpace, core_client, batch_client, kJobname, podName

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
    #   n|namespace         Kubernetes Name Space
    #   p|image_pull_policy Always or Latest
    #   r|restartpolicy     default is Never
    #   s|imagesecret       name of image_pull_secret
    #   t|volpath           Volume mount path in Pod
    #   v|envvalue          variable value
    #   y|yaml              name of a yaml manifest for job creation. Overrides all others except jobname
    #
    try:
       opts, arg = getopt.getopt(argv,"hb:c:e:H:i:j:m:n:p:r:s:t:v:y:",
            ["backofflimit=", 
             "claim=",
             "envname=", 
             "hostpath=",
             "image=",
             "jobname=",
             "volname=",
             "namespace=",
             "imagepullpolicy=",
             "restartpolicy=", 
             "imagepullsecret=", 
             "volpath="
             "envvalue=",
             "yaml="])
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
       elif opt in ("-n", "--namespace"):
          kNameSpace = arg

#   config.load_kube_config()                      # Out of cluster 
    config.load_incluster_config()                 # In cluster
    util_client = client.ApiClient()
    batch_client = client.BatchV1Api()
    core_client = client.CoreV1Api()
   
    if kYaml != '':
       print("Yaml file %s specified" % (kYaml))
       mNameSpace, mJobname = yamlload(kYaml)
       if kNameSpace == '':
          kNameSpace = mNameSpace
       if kJobname == '':
          kJobname = mJobname
       if mJobname != kJobname:
          print("Manifest job name \"%s\" and parameter job name \"%s\" do not match" % (mJobname, kJobname))
          sys.exit(16)
       if mNameSpace != kNameSpace:
          print("Manifest namespace \"%s\" and parameter namespace \"%s\" do not match" % (mNameSpace, kNameSpace))
          sys.exit(18)
       if kNameSpace == '':                  # If not in manifest or parameter, use default
          kNameSpace = "default"
       # Display options used for this execution      
       used_opts(kJobname, kYaml, kVname, kVvalue, kImagename, kimagepullpolicy, kimagepullsecret, krestartpolicy,
              kbackofflimit, khostpath, kvolname, kvolpath,kpvolclaim)
       startJob(util_client, batch_client, kJobname, kYaml)
    else:
       if kNameSpace == '':                  # If not specified, use default
          kNameSpace = "default"
       # Display options used for this execution      
       used_opts(kJobname, kYaml, kVname, kVvalue, kImagename, kimagepullpolicy, kimagepullsecret, krestartpolicy,
              kbackofflimit, khostpath, kvolname, kvolpath,kpvolclaim)
       job = create_job_object(kJobname, kImagename, kVname, kVvalue, kimagepullpolicy, kimagepullsecret, krestartpolicy, kbackofflimit, khostpath, kvolname, kvolpath, kpvolclaim)
       try:
           createJob(batch_client, job)
       except:
           print("Job creation failed")
           sys.exit(16)

    signal.signal(signal.SIGTERM, termSignal)

    time.sleep(5)                      # Give the job time to start a pod
    podName = listPod(core_client, kJobname)

    jobStatus, podsActive, podsSucceeded, podsFailed = status(batch_client, kJobname)

    print("Pods Statuses: %s Running / %s Succeeded / %s Failed" % (podsActive, podsSucceeded, podsFailed))
    print("Job Completion status: %d " % (jobStatus))
   
    deleteJob(batch_client, core_client, kJobname, podName)
   
    sys.exit(jobStatus)

if __name__ == '__main__':
    main(sys.argv[1:])