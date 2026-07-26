# Rails Structured Logging: Recommendations and Answers

Based on the research query regarding Rails structured logging, here are the detailed answers to your questions, specifically tailored for a Rails 8.1 stack with Puma, existing OpenTelemetry, and a SPARQL graph.

## 1. Best-Practice Structured Logging in Rails 8.1

The current landscape of structured logging in Rails 8.1 offers several paths, each with distinct trade-offs for a Puma-based application.

### Comparison of Logging Stacks

| Tool / Approach | Description | Pros | Cons |
| :--- | :--- | :--- | :--- |
| **`lograge`** | Replaces Rails' default verbose logging with a single structured line (JSON or key/value) per request. | Simple, well-known, effectively eliminates default Rails noise. | Request-centric; doesn't natively handle arbitrary background job logs or custom app logs as elegantly without extensions. Maintenance can sometimes lag major Rails releases. |
| **`semantic_logger` / `rails_semantic_logger`** | A comprehensive logging framework replacing the default Rails logger. Supports structured logging, tagging, asynchronous logging, and multiple appenders. | Highly mature, feature-rich, built-in async support (great for Puma), excellent JSON formatting, supports multiple simultaneous outputs (e.g., console + file + external service). | Heavyweight; replaces a lot of Rails internals. Can be complex to configure if you only need simple JSON. |
| **Rails Built-ins (`ActiveSupport::TaggedLogging`, etc.)** | Utilizing Rails' native tagging and event reporting capabilities, often combined with a custom JSON formatter. | No external dependencies, deeply integrated with Rails conventions. | Requires manual effort to format as JSON and filter out the noise. Doesn't natively solve the "one line per request" problem without significant custom event subscription work. |
| **OpenTelemetry Logs Bridge** | Emitting application logs directly as OpenTelemetry `LogRecord` objects, integrating them into the existing observability pipeline. | Unifies logs, metrics, and traces into a single pipeline and data model. Reduces infrastructure complexity. | The Ruby OTel Logs SDK has historically lagged behind Tracing and Metrics in maturity, though it is stabilizing. |

**Recommendation:** Given your existing OpenTelemetry setup, the **OpenTelemetry Logs Bridge** is the most forward-looking and cohesive choice, provided the Ruby SDK meets your stability requirements. If you need a robust, battle-tested alternative immediately, `semantic_logger` is the strongest standalone logging framework.

## 2. Reusing the OpenTelemetry Pipeline vs. Adding a JSON-Log Stack

**Yes, it absolutely makes sense to route app logs through your existing OpenTelemetry pipeline.**

Adding a separate JSON-log stack (like `semantic_logger` writing to a file, then parsed by Fluentd/Logstash) introduces redundant infrastructure when you already have an OTel collector running.

### OTel Ruby Logs SDK Maturity (as of 2026)

The OpenTelemetry Ruby Logs SDK has matured significantly and is now generally considered stable for production use. It supports the core OTel Logs Data Model, allowing you to emit structured `LogRecord` instances that correlate seamlessly with your existing traces and metrics.

By using the OTel pipeline, you achieve:
- **Unified Telemetry:** Logs, metrics, and traces share the same resource attributes and routing logic.
- **Simplified Infrastructure:** No need for separate log forwarders if the OTel collector can handle the volume.

**Conclusion:** Your leaning is correct. Composing with what you have (OTel) is vastly superior to bolting on a parallel system.

## 3. Noise Control: Taming SQL and Parameters

To stop SQL statements and large `Parameters:` payloads from dominating the log while retaining structured event lines, you need a multi-pronged approach.

### Strategies for Noise Reduction

1.  **Disable Verbose Query Logs:**
    Ensure `config.active_record.verbose_query_logs = false` in production (and potentially development if the noise is too high).
2.  **Filter Parameters:**
    Aggressively use `config.filter_parameters` to redact sensitive or massive payloads (e.g., `fs_write` bodies).
3.  **Adjust Log Levels:**
    Set the default log level to `INFO` or `WARN` in production. ActiveRecord queries are typically logged at the `DEBUG` level. By running at `INFO`, you automatically suppress the SQL query noise while keeping controller action summaries.
4.  **Event-Based Logging (The Real Fix):**
    If you use `lograge` or an OTel bridge, you typically unsubscribe from the noisy default Rails ActionController and ActiveRecord log subscribers and replace them with a single, structured event at the end of the request.

## 4. Queryability: Logs as Graph Events

Your proposed pattern of "logs as graph events" (projecting log events as triples into a named graph for SPARQL queries alongside `urn:mm:otel`) is highly intriguing but comes with caveats.

### Is "Logs as Graph Events" a Sane Pattern?

**It is a sane pattern ONLY IF strictly bounded and intentional.**

-   **The Anti-Pattern:** Dumping *all* raw application logs (every request, every debug line) into a SPARQL graph is an anti-pattern. Graph databases are generally not optimized for high-volume, append-only, unstructured text search or massive time-series log ingestion. It will bloat the graph and degrade performance.
-   **The Sane Pattern:** Projecting *high-value, structured business events* (which happen to be emitted via the logging/OTel pipeline) into the graph is excellent. For example, a `[fleet_ops_ground]` boot event with specific `ok/records/failed` metrics is highly relational and valuable in the graph.

**Pragmatic Path:**
1.  Emit all logs via OTel.
2.  Use the OTel Collector to filter and route.
3.  Send the bulk of routine logs to a cheap, searchable store (e.g., Elasticsearch, Loki, or even just structured JSON files queried via `jq` for local dev).
4.  Configure the OTel Collector (or a specific app-side OTel processor) to identify specific, high-value structured log events and project *only those* into the SPARQL graph.

## 5. Migration Shape: Least-Disruptive Rollout

To migrate an app with a large existing unstructured `development.log`, the goal is to maintain developer ergonomics while modernizing the pipeline.

### Rollout Strategy

1.  **Development Parity:**
    -   **Keep Human-Readable Output:** Developers rely on the visual cues of ANSI-colored, multi-line logs in their terminals. Do not force developers to read raw JSON in development.
    -   **Dual Appenders (or OTel Exporters):** Configure the logger to output pretty, formatted text to `STDOUT` (for the `rails server` console) while simultaneously writing structured JSON (or emitting OTel LogRecords) to a file or local collector. `semantic_logger` excels at this dual-output configuration natively. If using OTel, you can use a console exporter with a human-readable formatter alongside the OTLP exporter.
2.  **Production Rollout:**
    -   Switch entirely to the structured OTel output.
    -   Ensure the OTel collector is configured to receive and route the new log data appropriately before cutting over.

## Final Recommendation & Concrete Config Snippets

**Primary Path:** Confirming your leaning, the recommended path is to **emit app logs as OpenTelemetry LogRecords through the existing OTel pipeline**, keeping pretty console output in dev, and projecting only a bounded, intentional subset into the graph.

### Concrete Configuration (Conceptual OTel Logs Setup)

While specific Ruby code depends on the exact OTel SDK version, the conceptual setup involves configuring the OTel Logger Provider:

```ruby
# config/initializers/opentelemetry.rb

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'my-rails-app'
  # Existing trace/metrics config...
end

# Configure the Logger Provider
logger_provider = OpenTelemetry::SDK::Logs::LoggerProvider.new
logger_provider.add_log_record_processor(
  OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(
    OpenTelemetry::Exporter::OTLP::LogsExporter.new
  )
)

# Create a logger instance
otel_logger = logger_provider.logger(name: 'rails-app-logger')

# Bridge Rails logger to OTel (simplified example, often requires a custom formatter/broadcaster)
Rails.application.configure do
  if Rails.env.development?
    # Dual logging in dev: pretty console + OTel
    console_logger = ActiveSupport::Logger.new(STDOUT)
    # ... configure console_logger for human readability ...
    
    # You would typically use a broadcaster or a framework like semantic_logger 
    # to send to both console_logger and otel_logger
    config.logger = console_logger # Placeholder for dual setup
  else
    # Production: pure OTel
    config.logger = otel_logger
  end
end
```

### Addressing Your Leaning Directly

Your prior is structurally sound and aligns with modern observability practices. 

*   **Confirm:** Emitting via the existing OTel pipeline is the right architectural choice to avoid redundant systems.
*   **Confirm:** Keeping pretty console output in dev is crucial for developer experience.
*   **Confirm (with emphasis):** Projecting only a *bounded, intentional subset* of log-events into the SPARQL graph is critical. Do not use the graph as a general-purpose log sink.

This approach composes perfectly with your existing stack and adheres to your doctrine of structured events over scraped text.
