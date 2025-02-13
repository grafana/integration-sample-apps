# Istio sample app
This will spin up Istio (using various helm charts) in a minikube environment on a Multipass VM.
An Istio sample app (bookinfo) will be deployed as well.

Minimal load generation will also be carried after deployment is complete.

## Make

* `make run` - Used to start up the sample app. If there are no saved Prometheus or Loki server details, prompts will be given to enter URLs, user names, and passwords.
* `make stop` - Used to teardown the sample app.
* `make clean` - Used to cleanup the saved Prometheus and Loki server details.

## Prometheus metrics

The prometheus metrics endpoints exist on the bookinfo related pods in the default namespace at `http://localhost:15020/stats/prometheus`.

The prometheus metrics endpoint exists on the istiod pod in the istio-system namespace at `http://localhost:15020/metrics/`.
