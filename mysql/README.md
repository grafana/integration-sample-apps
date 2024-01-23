# MySQL Sample App

The default makefile action will request some configuration details, then launches a multipass VM running a MySQL server instance, and the Grafana Agent scraping it.

## MySQL Server

There is a MySQL user created for the agent to authenticate with. The credentials for that user are;
* Username: exporter
* Password: password