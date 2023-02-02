
https://compute.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances/{resourceId}

#   Get instance id
iid=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google"`
zone=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google"`


https://compute.googleapis.com/compute/v1/projects/631873438236/zones/northamerica-northeast1-a/instances/1976430076060061711



#   Get instance id
iid=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google"`
zone=`curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google"`
ctmenv=`gcloud compute instances describe $(hostname) --zone=${zone} --format="text(labels)" | grep ctmenvironment | cut -f 2 -d ':' | sed s/[^a-zA-Z0-9_-]//g`
ctmhgroup=`gcloud compute instances describe $(hostname) --zone=${zone} --format="text(labels)" | grep ctmhostgroup | cut -f 2 -d ':' | sed s/[^a-zA-Z0-9_-]//g`
