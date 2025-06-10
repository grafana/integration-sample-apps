# Netflow sample app

This file documents how to run [nflow-generator](https://github.com/nerdalert/nflow-generator) in combination with [ktranslate](https://github.com/kentik/ktranslate) in order to send data to Grafana Cloud.

It is currently not possible to run this in CI as it is not set up to deal with OTLP-only integrations.

## Prerequisites

Before you begin, ensure you have the following installed:

- Docker (or Podman)
- Git (for cloning the repository)

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**:
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/ktranslate-netflow
   ```

2. **Set up OTLP endpoint and credentials**:
   In `config.alloy`:
   * Set the `otelcol.exporter.otlphttp.grafana_cloud` endpoint to the OTLP endpoint of your Grafana Cloud stack.
   * Set the `otelcol.auth.basic.grafana_cloud` credentials to match the stack ID and Access Policy Token of your Grafana Cloud stack.

   You can find the required information in the [Grafana Cloud portal](https://grafana.com/docs/grafana-cloud/send-data/otlp/send-data-otlp/#manual-opentelemetry-setup-for-advanced-users)

3. **Run alloy**:
   Run the following to start alloy:
   ```
   docker run -d --name=netflow-alloy --net=host -v $PWD/config.alloy:/config.alloy:Z grafana/alloy:v1.9.1 run /config.alloy
   ```

4. **Run ktranslate**:
   Run ktranslate using this configuration:
   ```
   docker run -d --name="ktranslate" --cap-add net_raw --net=host quay.io/kentik/ktranslate:v2 \
     --format=otel \
     --otel.protocol=grpc \
     --otel.endpoint=http://localhost:4317/ \
     --nf.source=auto \
     --nf.port=9995 \
     --sinks=otel \
     --metrics=jhcf \
     --rollup_interval=60 \
     --tee_logs=true \
     --service_name=flow \
     --max_flows_per_message=100 \
     --rollups=s_sum,bytes_by_flow,in_bytes+out_bytes,src_addr,dst_addr,l4_src_port,l4_dst_port,protocol,custom_str.application,device_name,custom_str.src_host,custom_str.dst_host,src_geo,dst_geo \
     --rollup_keep_undefined=true
  ```

5. **Run nflow-generator**:
   Start generating new flows by running the following command:
   ```
   docker run --net host -it --rm docker.io/networkstatic/nflow-generator -t localhost -p 9995
   ```
