#!/bin/bash

# LDAP server configuration
LDAP_SERVER="ldap://localhost"
BASE_DN="dc=nodomain"
ADMIN_DN="cn=admin,$BASE_DN"
ADMIN_PW="pass"

# Function to add a number of LDAP entries
add_entries() {
    for i in $(seq 1 $1); do
        echo "dn: uid=user$i,$BASE_DN
objectClass: inetOrgPerson
cn: user$i
sn: user$i
uid: user$i
userPassword: pass$i
" | ldapadd -x -H "$LDAP_SERVER" -D "$ADMIN_DN" -w "$ADMIN_PW"
    done
}

# Function to modify an entry
modify_entry() {
    echo "dn: uid=user$1,$BASE_DN
changetype: modify
replace: sn
sn: newuser$1
" | ldapmodify -x -H "$LDAP_SERVER" -D "$ADMIN_DN" -w "$ADMIN_PW"
}

# Function to perform an LDAP search
search_entry() {
    ldapsearch -x -H "$LDAP_SERVER" -D "$ADMIN_DN" -w "$ADMIN_PW" -b "$BASE_DN" "uid=user$1"
}

# Function to delete an entry
delete_entry() {
    ldapdelete -x -H "$LDAP_SERVER" -D "$ADMIN_DN" -w "$ADMIN_PW" "uid=user$1,$BASE_DN"
}

# Function to perform multiple concurrent LDAP searches
parallel_searches() {
    for i in $(seq 1 $1); do
        ldapsearch -x -H "$LDAP_SERVER" -D "$ADMIN_DN" -w "$ADMIN_PW" -b "$BASE_DN" "(objectClass=*)" &
    done
    wait # Wait for all background processes to finish
}

# Function to perform a complex LDAP search
complex_search() {
    for i in $(seq 1 $1); do
        ldapsearch -x -H "$LDAP_SERVER" -D "$ADMIN_sDN" -w "$ADMIN_PW" -b "$BASE_DN" "(&(objectClass=inetOrgPerson)(uid=*))" &
    done
    wait # Wait for all searches to complete
}

# Function to add large entries (to increase memory usage)
add_large_entry() {
    local id=$1
    local largeData=$(head -c 1000000 </dev/urandom | tr -dc 'a-zA-Z0-9')  # Generate 1MB of random data
    echo "dn: uid=largeUser$id,$BASE_DN
objectClass: inetOrgPerson
cn: Large User$id
sn: Large$id
uid: largeUser$id
userPassword: largePass$id
description: $largeData
" | ldapadd -x -H "$LDAP_SERVER" -D "$ADMIN_DN" -w "$ADMIN_PW"
}

# Function to run LDAP operations for a certain duration (e.g., 1 minute)
run_operations_for_duration() {
    end=$((SECONDS+60)) # Run for 60 seconds
    while [ $SECONDS -lt $end ]; do
        for i in $(seq 1 100); do
            add_large_entry $i  # Add large entries
            complex_search 10   # Perform complex searches
            add_entries 1
            modify_entry $i
            search_entry $i
            delete_entry $i
            parallel_searches 10  # Perform 10 parallel searches
        done
    done
}

# Main loop to run operations and then wait
while true; do
    run_operations_for_duration
    sleep 600  # Wait for 600 seconds (10 minutes)
done
