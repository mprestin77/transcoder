# Media Transcoder


![image](https://user-images.githubusercontent.com/54962742/129648917-6e62834a-45d0-4a5d-a1ee-e6673fe080ca.png)

Data Flow:

A media file is uploaded to the source object storage  bucket. It emits an event that creates a transcoding request in OSS streaming queue. Job scheduler container running on OKE is monitoring the queue and when a new request arrives it starts a new transcoding job running as a container on OKE. The transcoding job uses ffmpeg open source software to transcode to multiple resolutions and different bitrates. It combines the video and audio for every HLS stream, packages each combination, and create individual TS segments and the playlists. On completion it creates a master manifest file, uploads all the files to the destination bucket and updates transcoded_files table in MySQL  "tc" database with the playlist.

Installation instructions:

1. In OCI console go to Development Services/Kubernetes Clusters (OKE) and create an OKE cluster with a nodepool on a private or public subnet

2. In Identity & Security/Dynamic Groups create a dynamic group that matches the compartment where OKE cluster was created. 

   All containers connect to OCI services using instance principal authentication.  Assign the following policies to the dynamic group:
   
   allow dynamic-group dynamic-group-name to manage streams in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage repos in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage object-family in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage secret-family in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage cluster-family in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage instance-family in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage virtual-network-family in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage cluster-node-pools in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to manage vnics in compartment id 'compartment OCID'
   
   allow dynamic-group dynamic-group-name to inspect compartments in compartment id 'compartment OCID'

3. Configure OKE cluster autoscaler following OCI documentation

   https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengusingclusterautoscaler.htm

4. Go to Analytics & AI/Streaming and create OSS stream "transcode". You can use the default settings with 1 partition.

5. Go to Databases/MySQL DB Systems and create a standalone MySQL DB system attached to the same subnet as the created OKE nodepool.

   Insure that in the subnet security list port tcp/3306 is open for traffic from your VCN.

6. Go to Networking/Virtual Cloud Network, select you VCN and add a service gateway to All 'region' Services In Oracle Services Network.

   Edit your subnet route table and add a route rule to All 'region' Services In Oracle Services Network" through the service gateway.
   
7. Create a staging/bastion VM attached to a public subnet on the same VCN. Install git, mysql-client, docker and kubectl on this VM

   sudo yum install git

   sudo yum install mysql

   sudo yum install docker

   sudo systemctl enable docker

   sudo systemctl start docker

   sudo usermod -a -G docker opc

   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  
   Logout and login back to your linux account. After that you should be able to run docker command without sudo. 

8. Download OKE cluster kube config file to the staging VM (replace 'cluster-OCID' and 'region-name' with your cluster OCID and region name)

   mkdir -p $HOME/.kube

   oci ce cluster create-kubeconfig --cluster-id 'cluster-OCID' --file $HOME/.kube/config --region 'region name'  --token-version 2.0.0  --kube-endpoint PRIVATE_ENDPOINT

   export KUBECONFIG=$HOME/.kube/config

9. Create OCIR repo in OCI console and login to the repo. Create an authentication token associated with your user in OCI console and run:

   docker login 'region'.ocir.io

   Replace region with iad for "us-ashburn-1" or phx for "us-phonix-1", etc... 
   This commands prompts you with user & password. For IDCS users as a username use 'tenancy-name'/oracleidentitycloudservice/'user-name'.
   The password is the authentication token that you created.

10. Create "transcode" k8s namespace

   kubectl create namespace transcode

11. Clone github files to the staging VM:

    git clone https://github.com/mprestin77/transcoder.git

    It should create a "transcoder" directory with the files cloned from the github

12. Go to transcoder/oke directory. Edit the script create_ocir_secret.sh script and set OCIR_USERNAME, DOCKER_SERVER, DOCKER_EMAIL variables. 

    Run the script to create ocirsecret for pulling container images from OCI. Check  that the secret is created

    kubectl -n transcode get secrets

13. Go to transcoder/mysql directory and edit create_db.sh script. Set the values for:

    DB_HOST="MySQL DB system private IP address"

    DB_ADMIN_USER="MySQL admin user"   

    The script first prompts you to enter MySQL Admin user password (that you used when creating MySQL DB system) and then to enter MySQL "tc" user password.

    create_db.sh script connects using mysql client to MySQL DB system that you created on OCI through TCP port 3306. 

    If the script cannot connect to MySQL DB check that the port tcp/3306 is open in the security list of the subnet where MySQL DB system is attached.
  
14. Create a k8s secret to with MySQL "tc" user password. Enrypt MySQL "tc" user password

    echo -n 'enter mysql DB password' | base64

    This command returns base64 encrypted value of the password.  Go to transcoder/oke directory and edit db-secret.yaml file setting "password" to the encrypted string.

    After the file is updated create db-password secret

    kubectl -n transcode apply -f db-secret.yaml  

    and check that the db-secret is created

    kubectl -n transcode get secrets

15. Go to transcoder/scheduler directory.  Edit build.sh script and set OCIR_REPO variable to your OCIR repo path.

    Run buiuld.sh script. It builds "scheduler:latest" container image and uploads it to your OCIR repo.

16. Go to transcoder/transcode directory. Edit build.sh script and set OCIR_REPO variable to your OCIR repo path.

    Run buiuld.sh script. It builds "transcoder:latest" container image and uploads it to your OCIR repo. 

17. Go to transcoder/oke directory. Edit scheduler.yaml file and search for 'OCIR repo path'. Replace it with your OCIR repo path.

18. Edit configmap.yaml file and set the values of variables

    TC_STREAM_ENDPOINT: "Streaming queue endpoint URL"

    TC_STREAM_OCID: "OCID of the streaming queue"

    TC_SRC_BUCKET: "Name of the source OS bucket"

    TC_DST_BUCKET: "Name of the output OS bucket"

    TC_OS_NAMESPACE: "OS namespace (could be different from the tenancy name)"

    TC_OKE_NODEPOOL: "OKE nodepool k8s label (could be different from the nodepool name)"

    TC_OCIR_REPO: "OCIR repo path"

    TC_DB_HOST: "mysql DB system private IP address"

    Make sure that you have double quotes around every value

    Optionally you can edit FFMPEG paramaters. With the current settings FFMPEG is configured for hls transcoding with 3 output streams scaling to 1920x1080, 1280x720, 640x360

    Create configmap

    kubectl -n transcode -f configmap.yaml

19. Deploy scheduler.yaml 

    kubectl -n transcode apply -f scheduler.yaml

    It creates k8s service account, role and rolebinding and deploys job-scheduler container.

    Check that job-scheduler container is running:

    kubectl -n transcode get pods

    You should see job-scheduler container has RUNNING status. If it fails to start get the pod log by running

    kubectl -n describe "pod NAME"

    If the container starts but get into ERROR state check the contaner log

    kubectl -n logs "pod NAME" 

20. Go to Observability & Management/Event Service in OCI console and create an event rule:

    Rule Conditions:

    Condition="Event Type" :  Service-Name="Object Storage" Event-Type: "Object - Create"

    Condition="Attribute" : Attribute-Name="name of the source OS bucket"

    Actions:

    Action Type="Streaming" Streaming-Compartment="your compartment name"

21. Upload a new video file to the source OS bucket and check in Event Metrics that a new event is emitted. 

    If you see a new event emitted, go to OSS stream and check in OSS Metrics that a new request is added to the queue

    After that check that a new transcoder job is created

    kubectl -n transcode get pods

    You should see a transcoder pod is running. If the pod fails describe it and check the log.

    If you see a transcoder pod you can attach to the container log by running

    kubectl -n logs "pod NAME" --follow
    

