
### Create your DD_API_KEY:

- (Create and) Log in to your Datadog account (e.g., at app.datadoghq.com for the US region or app.datadoghq.eu for the EU region).
- Navigate to Organization Settings > API Keys (usually under your user profile or Integrations).
- Create a new API key or copy an existing one. It’s a 32-character alphanumeric string, e.g., a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.
- Do not share this key publicly—it’s sensitive and grants access to your Datadog account.

### Configure  OpenTelemetry(otel) for OTLP export. 

**install otel instegration in your https://us5.datadoghq.com/integrations/otel **
- search in the website with keyword : otel
- click on `otel integrtion`
- click `install`

**Configuration guide provided in website after successful installation:** (i did not use it.)
```
This integration is working properly.
Configuration
Installation
Follow the [OpenTelemetry Collector documentation](https://opentelemetry.io/docs/collector/getting-started/) to install the opentelemetry-collector-contrib distribution, or any other distribution that includes the Datadog Exporter.

The Datadog Agent is not needed to export telemetry data to Datadog in this setup. See [OTLP Ingest in Datadog Agent](https://docs.datadoghq.com/tracing/setup_overview/open_standards/otlp_ingest_in_the_agent/) if you want to use the Datadog Agent instead.

Configuration
To export telemetry data to Datadog from the OpenTelemetry Collector, add the Datadog exporter to your metrics and traces pipelines. The only required setting is your API key.

A minimal configuration file to retrieve system metrics is as follows.

receivers:
  hostmetrics:
    scrapers:
      load:
      cpu:
      disk:
      filesystem:
      memory:
      network:
      paging:
      process:

processors:
  batch:
    timeout: 10s

exporters:
  datadog:
    api:
      key: "<Your API key goes here>"
      
service:
  pipelines:
    metrics:
      receivers: [hostmetrics]
      processors: [batch]
      exporters: [datadog]
For further information on the Datadog exporter settings and how to configure the pipeline, see [Datadog exporter for OpenTelemetry Collector](https://docs.datadoghq.com/tracing/setup_overview/open_standards/otel_collector_datadog_exporter/).

See the [Metrics section](https://docs.datadoghq.com/metrics/otlp/) for metrics types and [metadata.csv](https://github.com/DataDog/integrations-core/blob/master/otel/metadata.csv) for a list of metrics provided by this check. If you're using the hostmetrics receiver as in the sample configuration above. You can send arbitrary metrics with other OpenTelemetry Collector components.

Different groups of metrics can be enabled and customized by following the [hostmetrics receiver instructions](https://github.com/open-telemetry/opentelemetry-collector/tree/master/receiver/). CPU and disk metrics are not available on macOS.

Validation
Check the OpenTelemetry Collector logs to see the Datadog exporter being enabled and started correctly. For example, with the configuration above you should find logging messages similar to the following.

Exporter is enabled.	{"component_kind": "exporter", "exporter": "datadog"}
Exporter is starting...	{"component_kind": "exporter", "component_type": "datadog", "component_name": "datadog"}
Exporter started.	{"component_kind": "exporter", "component_type": "datadog", "component_name": "datadog"}
Everything is ready. Begin running and processing data.

Uninstallation
For integrations running on the Agent:
Fully remove the integration by following the datadog-agent integration remove command. More information can be found [here](https://docs.datadoghq.com/agent/guide/integration-management/?tab=linux#remove).
Click ‘Uninstall’ to remove the included assets, such as dashboards, from your organization.
```


