# Custom Varnish Helm chart

This helm chart is based on the [official chart](https://artifacthub.io/packages/helm/varnish/varnish-cache) released by Varnish Software. It is for development
purposes only and we've added the following:
* An NGINX sidecar as a backend for Varnish cache
* A custom configuration map for the NGINX configuration
* An exporter sidecar for Prometheus metrics
