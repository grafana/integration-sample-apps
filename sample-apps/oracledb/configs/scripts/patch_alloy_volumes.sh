#!/bin/bash

# Patch Alloy StatefulSet to add Oracle Instant Client volumes
# This script patches the deployed Alloy StatefulSet to mount the Oracle client PVC
# This is sort of a workaround to get the Oracle client for Alloy to use to connect to the Oracle DB

set -e

echo "Patching Alloy StatefulSet to add Oracle Instant Client volumes..."

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Detect architecture and map to GNU triplet
DPKG_ARCH=$(dpkg --print-architecture)
case $DPKG_ARCH in
  arm64) GNU_ARCH=aarch64-linux-gnu;;
  amd64) GNU_ARCH=x86_64-linux-gnu;;
  *) GNU_ARCH=$DPKG_ARCH-linux-gnu;;
esac

echo "Detected architecture: $DPKG_ARCH (GNU: $GNU_ARCH)"

# Create the patch for adding volumes and volume mounts with init container for dependencies
cat << EOF > /tmp/alloy-volumes-patch.json
{
  "spec": {
    "template": {
      "spec": {
        "initContainers": [
          {
            "name": "setup-oracle-deps",
            "image": "ubuntu:24.04",
            "command": ["sh", "-c"],
            "args": [
              "apt-get update && apt-get install -y libaio1t64 && cp /usr/lib/${GNU_ARCH}/libaio.so.1t64* /shared-libs/ && cd /shared-libs && ln -sf libaio.so.1t64 libaio.so.1 && echo 'Oracle dependencies copied to shared volume for architecture: ${DPKG_ARCH} (GNU: ${GNU_ARCH})'"
            ],
            "volumeMounts": [
              {
                "name": "shared-libs",
                "mountPath": "/shared-libs"
              }
            ]
          }
        ],
        "volumes": [
          {
            "name": "oracle-instant-client-libs",
            "persistentVolumeClaim": {
              "claimName": "oracle-instant-client-libs"
            }
          },
          {
            "name": "shared-libs",
            "emptyDir": {}
          }
        ],
        "containers": [
          {
            "name": "alloy",
            "volumeMounts": [
              {
                "name": "oracle-instant-client-libs",
                "mountPath": "/usr/lib/oracle",
                "readOnly": true
              },
              {
                "name": "shared-libs",
                "mountPath": "/usr/lib/oracle-extra-libs"
              }
            ],
            "env": [
              {
                "name": "ORACLE_HOME",
                "value": "/usr/lib/oracle/instantclient"
              },
              {
                "name": "LD_LIBRARY_PATH",
                "value": "/usr/lib/oracle/instantclient/lib:/usr/lib/oracle-extra-libs"
              }
            ]
          }
        ]
      }
    }
  }
}
EOF

echo "Applying patch to k8s-monitoring-alloy StatefulSet..."
kubectl patch statefulset k8s-monitoring-alloy -n monitoring --type='strategic' --patch-file=/tmp/alloy-volumes-patch.json

echo "Waiting for StatefulSet to roll out..."
kubectl rollout status statefulset/k8s-monitoring-alloy -n monitoring --timeout=120s
kubectl exec -n monitoring k8s-monitoring-alloy-0 -- ls -la /usr/lib/oracle/ || echo "Mount verification failed - checking pod status..."

if ! kubectl exec -n monitoring k8s-monitoring-alloy-0 -- ldd /usr/lib/oracle/instantclient/lib/libnnz.so | grep libaio; then
  echo "libaio check failed"
  exit 1
fi

echo "Alloy StatefulSet patched successfully!"
echo "Oracle Instant Client should now be available at /usr/lib/oracle/"
echo "Oracle dependencies (libaio) should be installed and linked"
