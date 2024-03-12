variable "loadgen_script" {
  default = <<EOF
#!/bin/bash

SCALE=2
SLEEP_DURATION=300 # 5 minutes
DISK_IMAGE=cirros-0.6.2-x86_64-disk

source openrc

# Create instances
openstack server create --flavor m1.small --image $DISK_IMAGE --network private test-server-small
openstack server create --flavor m1.medium --image $DISK_IMAGE --network private test-server-medium

# Create volumes
openstack volume create --size 5 --image $DISK_IMAGE test-volume-1
openstack volume create --size 10 --image $DISK_IMAGE test-volume-2

# Confirm volume status before continuing
test $(openstack volume show test-volume-1 -f value -c status) = "available"
while [ $? = 1 ]; do
  test $(openstack volume show test-volume-1 -f value -c status) = "available"
done
test $(openstack volume show test-volume-2 -f value -c status) = "available"
while [ $? = 1 ]; do
  test $(openstack volume show test-volume-2 -f value -c status) = "available"
done

# Create snapshots
openstack volume snapshot create test-snapshot-1 --volume test-volume-1
openstack volume snapshot create test-snapshot-2 --volume test-volume-2

# Attach volumes to instances
openstack server add volume test-server-small test-volume-1
openstack server add volume test-server-medium test-volume-2

# Create backups
openstack volume backup create test-volume-1
openstack volume backup create test-volume-2

# Create floating IPs
openstack floating ip create public

# Create network
openstack network create test-network-1

# Create subnet: 
openstack subnet create test-subnet-1 --network test-network-1 --subnet-range 192.0.2.0/19

# Create router:
openstack router create test-router-1
openstack router create test-router-2


while true; do

  # Create more resources
  scale_resources() {
    echo "Scaling up the environment"
    for ((i=1; i<=SCALE; i++)); do
      openstack server create --flavor m1.tiny --image $DISK_IMAGE --network private test-server-scale-$i
      openstack volume create --size 3 --image $DISK_IMAGE test-volume-scale-$i
      test $(openstack volume show test-volume-scale-$i -f value -c status) = "available"
      while [ $? = 1 ]; do
        test $(openstack volume show test-volume-scale-$i -f value -c status) = "available"
      done
      openstack volume snapshot create test-snapshot-scale-$i --volume test-volume-scale-$i
      openstack server add volume test-server-scale-$i test-volume-scale-$i
      openstack volume backup create --name test-backup-scale-$i test-volume-scale-$i 
      openstack floating ip create public
      openstack floating ip create public
      openstack network create test-network-scale-$i
      openstack subnet create test-subnet-scale-$i --network test-network-scale-$i --subnet-range 192.0.2.0/2$i
      openstack router create test-router-scale-$i
    done
    echo "Scaling complete"
  }

  delete_resources() {
    echo "Removing newly generated resources from the environment"
    for ((i=1; i<=SCALE; i++)); do
      openstack volume snapshot delete test-snapshot-scale-$i
      openstack volume backup delete test-backup-scale-$i
      openstack server remove volume test-server-scale-$i test-volume-scale-$i
      openstack server delete test-server-scale-$i
      openstack volume delete test-volume-scale-$i

      # Delete floating ips
      output=$(openstack floating ip list -c ID -f value)
      $(IFS= read -r flip_id1 && IFS= read -r flip_id2;) <<< $output
      openstack floating ip delete $flip_id1
      openstack floating ip delete $flip_id2
      openstack network delete test-network-scale-$i
      openstack subnet delete test-subnet-scale-$i  
      openstack router delete test-router-scale-$i
    done
    echo "Scaling complete"
  }

  # Call functions
  scale_resources
  sleep $SLEEP_DURATION
  delete_resources
  sleep $SLEEP_DURATION
done
EOF
}
