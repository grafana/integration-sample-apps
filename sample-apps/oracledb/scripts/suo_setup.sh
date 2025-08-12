#!/bin/sh

# Re-set the KUBECONFIG since multipass exec does not load .profile or .bashrc correctly
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

sudo apt-get update && sudo apt-get install -y docker.io 

cd /home/ubuntu/configs/oracle-client-installer
sudo docker build -t oracle/oracle-client-installer:0.0.1 .
sudo docker image save -o oracle-client-installer.tar oracle/oracle-client-installer:0.0.1
sudo ctr images import oracle-client-installer.tar

rm -rf /home/ubuntu/configs/oracle-client-installer/oracle-client-installer.tar


cd /home/ubuntu/configs

# Setup Oracle Instant Client with PVC
/home/ubuntu/configs/scripts/setup_oracle_client.sh

# Install Oracle DB
helm install oracledb . --namespace oracledb \
    --create-namespace \
    --values /home/ubuntu/configs/values.yaml \
    --wait


# Wait for Oracle database to be fully ready
echo "Waiting for Oracle database to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/app=oracledb -n oracledb --timeout=600s

kubectl exec -it -n oracledb deployment/oracledb -- sqlplus / as sysdba << 'EOF'
ALTER SESSION SET CONTAINER = FREEPDB1;
CREATE USER grafanau IDENTIFIED BY r7DC98o8Op;

GRANT CONNECT TO grafanau;
GRANT CREATE SESSION TO grafanau;

GRANT SELECT ON SYS.GLOBAL_NAME TO grafanau;
GRANT SELECT ON SYS.V_$DATABASE TO grafanau;
GRANT SELECT ON SYS.V_$SESSION TO grafanau;
GRANT SELECT ON SYS.V_$PROCESS TO grafanau;
GRANT SELECT ON SYS.V_$SYSSTAT TO grafanau;
GRANT SELECT ON SYS.V_$SYSMETRIC TO grafanau;
GRANT SELECT ON SYS.V_$RESOURCE_LIMIT TO grafanau;
GRANT SELECT ON SYS.V_$WAITCLASSMETRIC TO grafanau;
GRANT SELECT ON SYS.V_$SYSTEM_WAIT_CLASS TO grafanau;
GRANT SELECT ON SYS.V_$DATAFILE TO grafanau;
GRANT SELECT ON SYS.V_$ASM_DISKGROUP_STAT TO grafanau;
GRANT SELECT ON SYS.V_$SQLSTATS TO grafanau;

GRANT SELECT ON SYS.DBA_TABLESPACES TO grafanau;
GRANT SELECT ON SYS.DBA_TABLESPACE_USAGE_METRICS TO grafanau;
EOF

echo "Oracle database setup and monitoring permissions configuration complete!" 