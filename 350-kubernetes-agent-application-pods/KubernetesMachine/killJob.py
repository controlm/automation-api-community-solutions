
from os import path
from kubernetes import client, config, utils

import sys, getopt, time

kNameSpace = "default"
stime = 15				# Default sleep interval for status check

def main(argv):
   global kNameSpace
   kJobname = ''
   outputfile = ''
   try:
     opts, args = getopt.getopt(argv,"hj:",["jname="])
   except getopt.GetoptError:
     print("runjob.py -j <jobname>")
     sys.exit(2)
   for opt, arg in opts:
     if opt == '-h':
        print("runjob.py -j <jobname>")
        sys.exit()
     elif opt in ("-j", "--jname"):
        kJobname = arg

   print("Killing job: " + kJobname)
     
   podName = listPod(kJobname)
   deleteJob(kJobname)
   getLog(podName)
   deletePod(podName)
   
   quit(0)
       
def listPod(kJobname):
   config.load_kube_config()
   coreV1 = client.CoreV1Api()
   podLabelSelector = 'job-name=' + kJobname
   print("Listing pod for jobname:" + kJobname)
   ret = coreV1.list_namespaced_pod(kNameSpace, label_selector=podLabelSelector)
   for i in ret.items:
      podName = str(i.metadata.name)
      print("%s" %
          (i.metadata.name))
   return podName

  
def getLog(podName):
   config.load_kube_config()
   coreV1 = client.CoreV1Api()
   ret = coreV1.read_namespaced_pod_log(podName, kNameSpace)
   print("Log output from Pod: " + podName)
   print(ret)
   return
   
def deleteJob(kJobname):
   config.load_kube_config()
   jobBody = client.V1Job()
   batchV1 = client.BatchV1Api()
   ret = batchV1.delete_namespaced_job(kJobname, kNameSpace, jobBody)
   print("Job deleted: " + kJobname)
   
   return
   
def deletePod(podName):
   config.load_kube_config()   
   podBody = client.V1DeleteOptions()
   coreV1 = client.CoreV1Api()
   ret = coreV1.delete_namespaced_pod(podName, kNameSpace, podBody)
   print("Pod deleted: " + podName)
   
   return
if __name__ == '__main__':
   main(sys.argv[1:])
