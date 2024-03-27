velero backup create demo-0 --include-namespaces demo-0 

velero backup create demo-1 --include-namespaces demo-1 

kubectl delete ns demo-0 

kubectl delete ns demo-1

velero create restore --from-backup demo-0

velero create restore --from-backup demo-1

