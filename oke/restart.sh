kubectl -n transcode delete jobs --all
pod_name=`kubectl -n transcode get pods | grep scheduler | cut -d ' ' -f1`
kubectl -n transcode delete pod $pod_name

