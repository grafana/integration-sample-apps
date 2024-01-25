# Envoy Sample App

The default makefile action will request some configuration details, then launch a multipass VM running an Envoy instance, and the Grafana Agent scraping it.

The Envoy process runs only in interactive mode, so when you execute `make` it will continue to run in your terminal until interrupted.