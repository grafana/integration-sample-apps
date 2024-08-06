## Generating the provisioner yaml
If you ever need to update the version of the provisioner, you can run the following command and it'll generate a file. You may need to delete the existing yaml file.

```bash
helm template my-nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=nfs-service.default.svc.cluster.local --set nfs.path=/nfsshare > nfs-provisioner.yaml
```

