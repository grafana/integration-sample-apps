#!/bin/bash

VM_NAME=$1

# Install OpenLDAP and ldap-utils
multipass exec "$VM_NAME" -- sudo apt update
multipass exec "$VM_NAME" -- sudo apt install -y slapd ldap-utils

# Reconfigure slapd - This step might need manual intervention
multipass exec "$VM_NAME" -- sudo dpkg-reconfigure slapd

# Generate the hashed password inside the VM and store it in a file
multipass exec "$VM_NAME" -- bash -c "slappasswd -s pass > /tmp/hashed_password.txt"

# Read the hashed password from the file inside the VM and create monitor user
multipass exec "$VM_NAME" -- bash -c "HASHED_PASSWORD=\$(cat /tmp/hashed_password.txt) && echo -e \"dn: cn=monitor,dc=nodomain\nobjectClass: simpleSecurityObject\nobjectClass: organizationalRole\ncn: monitor\ndescription: LDAP monitor\nuserPassword: \$HASHED_PASSWORD\" > cn_monitor.ldif"

# Enable the monitoring module
echo -e "dn: cn=module{0},cn=config\nchangetype: modify\nadd: olcModuleLoad\nolcModuleLoad: back_monitor" | multipass exec "$VM_NAME" -- sudo tee module_monitor.ldif
multipass exec "$VM_NAME" -- sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f module_monitor.ldif

# Add monitor user to LDAP
multipass exec "$VM_NAME" -- sudo ldapadd -x -D "cn=admin,dc=nodomain" -w pass -f cn_monitor.ldif

# Setup the monitor database
echo -e "dn: olcDatabase={2}Monitor,cn=config\nobjectClass: olcDatabaseConfig\nobjectClass: olcMonitorConfig\nolcDatabase: {2}Monitor\nolcAccess: to dn.subtree=\"cn=Monitor\" by dn.base=\"cn=monitor,dc=nodomain\" read by * none" | multipass exec "$VM_NAME" -- sudo tee database_monitor.ldif
multipass exec "$VM_NAME" -- sudo ldapadd -Y EXTERNAL -H ldapi:/// -f database_monitor.ldif

# Remove the hashed password file inside the VM for security
multipass exec "$VM_NAME" -- sudo rm /tmp/hashed_password.txt

echo "LDAP setup completed."
