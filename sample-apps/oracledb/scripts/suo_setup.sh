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

echo "Installing Oracle DB..."
# Install Oracle DB
helm install oracledb . --namespace oracledb \
    --create-namespace \
    --values /home/ubuntu/configs/values.yaml \
    --wait


# Wait for Oracle database to be fully ready
echo "Waiting for Oracle database to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/app=oracledb -n oracledb --timeout=600s

kubectl exec -it -n oracledb deployment/oracledb -- sqlplus / as sysdba << 'EOF'
ALTER SESSION SET CONTAINER = CDB$ROOT;
CREATE USER C##GRAFANAU IDENTIFIED BY "r7DC98o8Op";
GRANT CREATE SESSION TO C##GRAFANAU;

GRANT CONNECT TO C##GRAFANAU;

GRANT SELECT ON SYS.GLOBAL_NAME TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$DATABASE TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$SESSION TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$PROCESS TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$SYSSTAT TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$SYSMETRIC TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$RESOURCE_LIMIT TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$WAITCLASSMETRIC TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$SYSTEM_WAIT_CLASS TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$DATAFILE TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$ASM_DISKGROUP_STAT TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$SQLSTATS TO C##GRAFANAU;
GRANT SELECT ON SYS.V_$PARAMETER TO C##GRAFANAU;

GRANT SELECT ON SYS.DBA_TABLESPACES TO C##GRAFANAU;
GRANT SELECT ON SYS.DBA_TABLESPACE_USAGE_METRICS TO C##GRAFANAU;
ALTER USER C##GRAFANAU SET CONTAINER_DATA = ALL CONTAINER = CURRENT;
EOF

echo "Oracle database setup and monitoring permissions configuration complete!" 
