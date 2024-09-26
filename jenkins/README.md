# Jenkins Sample App

The default makefile action will request some configuration details, then launch a multipass VM running a Jenkins instance, and the Grafana Agent scraping it.

## Jenkins Instance

You can access the jenkins instance at http://<ip_of_multipass_vm>:8080/.

You can acquire the IP using `multipass info jenkins-sample-app --format json | jq -r '.info."jenkins-sample-app".ipv4[0]'`

The username is "admin" and the password is "password".

The data for the Jenkins instance is stored in `./multipass_mounts/varlibjenkins.zip`, and is automatically expanded and mounted into the multipass VM when running `make`.