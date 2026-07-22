///|
/// Structured logging for mbit — powered by `moonbit-log` (`leppard/moonbit-log`).
///
/// ## Usage
///
/// ```
/// // Configure global logger
/// set_log_level(Info)
/// set_log_format(JSONFormat)
///
/// // In middleware / handlers
/// log_debug("Processing request", [("path", ctx.path())])
/// log_info("User logged in", [("user_id", "42"), ("ip", ctx.client_ip())])
/// log_error("Database timeout", [("query", "SELECT ...")])
///
/// // Structured request logging middleware
/// app.use(structured_logger(StructuredLogConfig::default()))
/// ```

///|
/// Log severity levels — maps to `@leppard/moonbit-log.Level`.
pub(all) enum LogLevel {
  Debug
  Info
  Warn
  Error
  Fatal
} derive(Debug, Eq, Hash, Compare)

///|
/// Log output format.
pub(all) enum LogFormat {
  /// Human-readable text output (default)
  TextFormat
  /// JSON lines (suitable for log aggregators like ELK, Datadog)
  JSONFormat
} derive(Debug, Eq)

///|
/// Convert LogLevel to string.
pub fn LogLevel::to_string(self : LogLevel) -> String {
  match self {
    Debug => "DEBUG"
    Info => "INFO"
    Warn => "WARN"
    Error => "ERROR"
    Fatal => "FATAL"
  }
}

///|
/// Convert our LogLevel to the underlying `@leppard/moonbit-log.Level`.
fn to_log_level(level : LogLevel) -> @leppard/moonbit-log.Level {
  match level {
    Debug => @leppard/moonbit-log.Level::Debug
    Info => @leppard/moonbit-log.Level::Info
    Warn => @leppard/moonbit-log.Level::Warn
    Error => @leppard/moonbit-log.Level::Error
    Fatal => @leppard/moonbit-log.Level::Fatal
  }
}

///|
/// Global logger configuration state.
priv struct LoggerConfig {
  mut level : LogLevel
  mut _format : LogFormat
  mut app_name : String
  mut environment : String
}

///|
/// Default logger configuration.
let global_config : LoggerConfig = {
  level: Debug,
  _format: TextFormat,
  app_name: "mbit",
  environment: "development",
}

///|
/// Set the minimum log level.
pub fn set_log_level(level : LogLevel) -> Unit {
  global_config.level = level
  // Also update moonbit-log's global logger level
  let ml_level = to_log_level(level)
  let logger = @leppard/moonbit-log.get_global_logger()
  logger.set_level(ml_level)
}

///|
/// Get the current log level.
pub fn log_level() -> LogLevel {
  global_config.level
}

///|
/// Set the log output format.
/// - `TextFormat`: human-readable compact format
/// - `JSONFormat`: JSON lines format
pub fn set_log_format(format : LogFormat) -> Unit {
  global_config._format = format
  match format {
    TextFormat => @leppard/moonbit-log.init_default_console()
    JSONFormat => @leppard/moonbit-log.init_default_json()
  }
}

///|
/// Set the application name for log metadata.
/// The app name is injected as a field into every log entry.
pub fn set_log_app_name(name : String) -> Unit {
  global_config.app_name = name
}

///|
/// Set the environment tag for log metadata.
/// Injected as a field ("env") into every log entry.
pub fn set_log_environment(env : String) -> Unit {
  global_config.environment = env
}

///|
/// Enable or disable caller reporting in logs.
/// (Delegated to moonbit-log's LogEntryBuilder; currently always reports.)
pub fn set_log_report_caller(_report : Bool) -> Unit {
  // moonbit-log always captures file/line info in LogEntry
}

///| ——————————————————————————————————————————————————————————————————————
///  Core logging functions — delegate to moonbit-log global API
///| ——————————————————————————————————————————————————————————————————————

///|
/// Check if the given log level is enabled.
pub fn is_log_enabled(level : LogLevel) -> Bool {
  level >= global_config.level
}

///|
/// Build the base fields array with app name and environment.
fn base_fields() -> Array[(String, String)] {
  let fields : Array[(String, String)] = []
  if global_config.app_name != "" {
    fields.push(("app", global_config.app_name))
  }
  if global_config.environment != "" {
    fields.push(("env", global_config.environment))
  }
  fields
}

///|
/// Log a debug message with optional key-value fields.
///
/// ```
/// log_debug("Cache miss", [("key", "user:42")])
/// ```
pub fn log_debug(message : String, fields~ : Array[(String, String)] = []) -> Unit {
  let all_fields = base_fields()
  for f in fields { all_fields.push(f) }
  if all_fields.length() > 0 {
    @leppard/moonbit-log.g_log_with(@leppard/moonbit-log.Level::Debug, message, all_fields)
  } else {
    @leppard/moonbit-log.g_debug(message)
  }
}

///|
/// Log an info message with optional key-value fields.
pub fn log_info(message : String, fields~ : Array[(String, String)] = []) -> Unit {
  let all_fields = base_fields()
  for f in fields { all_fields.push(f) }
  if all_fields.length() > 0 {
    @leppard/moonbit-log.g_log_with(@leppard/moonbit-log.Level::Info, message, all_fields)
  } else {
    @leppard/moonbit-log.g_info(message)
  }
}

///|
/// Log a warning message with optional key-value fields.
pub fn log_warn(message : String, fields~ : Array[(String, String)] = []) -> Unit {
  let all_fields = base_fields()
  for f in fields { all_fields.push(f) }
  if all_fields.length() > 0 {
    @leppard/moonbit-log.g_log_with(@leppard/moonbit-log.Level::Warn, message, all_fields)
  } else {
    @leppard/moonbit-log.g_warn(message)
  }
}

///|
/// Log an error message with optional key-value fields.
pub fn log_error(message : String, fields~ : Array[(String, String)] = []) -> Unit {
  let all_fields = base_fields()
  for f in fields { all_fields.push(f) }
  if all_fields.length() > 0 {
    @leppard/moonbit-log.g_log_with(@leppard/moonbit-log.Level::Error, message, all_fields)
  } else {
    @leppard/moonbit-log.g_error(message)
  }
}

///|
/// Log a fatal message and terminate.
pub fn log_fatal(message : String, fields~ : Array[(String, String)] = []) -> Unit {
  let all_fields = base_fields()
  for f in fields { all_fields.push(f) }
  if all_fields.length() > 0 {
    @leppard/moonbit-log.g_log_with(@leppard/moonbit-log.Level::Fatal, message, all_fields)
  } else {
    @leppard/moonbit-log.g_fatal(message)
  }
  abort(message)
}

///| ——————————————————————————————————————————————————————————————————————
///  Structured request logging middleware
///| ——————————————————————————————————————————————————————————————————————

///|
/// Configuration for the structured request logger middleware.
pub(all) struct StructuredLogConfig {
  /// Log level for request logs
  level : LogLevel
  /// Whether to log the request body
  log_request_body : Bool
  /// Whether to log the response body
  log_response_body : Bool
  /// Maximum body length to log (in bytes, 0 = unlimited)
  max_body_log_length : Int
  /// Whether to skip logging for specific paths
  skip_paths : Array[String]
  /// Whether to include latency in logs
  include_latency : Bool
  /// Additional static fields to include in every request log
  static_fields : Array[(String, String)]
}

///|
/// Default structured log config.
pub fn StructuredLogConfig::default() -> StructuredLogConfig {
  {
    level: Info,
    log_request_body: false,
    log_response_body: false,
    max_body_log_length: 1024,
    skip_paths: ["/health", "/metrics"],
    include_latency: true,
    static_fields: [],
  }
}

///|
/// Structured request logging middleware — powered by moonbit-log.
///
/// Logs each request with structured fields:
/// - method, path, status, latency
/// - client_ip, user_agent, content_type
/// - request_id (if set in context)
///
/// ```
/// app.use(structured_logger(StructuredLogConfig::default()))
/// ```
pub fn structured_logger(config : StructuredLogConfig) -> Handler {
  async fn(ctx) {
    // Check skip paths
    let path = ctx.path()
    for skip in config.skip_paths {
      if path == skip {
        ctx.next()
        return
      }
    }

    let start = @env.now()
    let method = ctx.http_method()
    let client_ip = ctx.client_ip()
    let user_agent = match ctx.header("User-Agent") {
      Some(ua) => ua
      None => ""
    }
    let content_type = ctx.content_type()

    // Run the handler chain
    ctx.next()

    let elapsed = @env.now() - start
    let status = ctx.status_code

    // Build structured fields
    let fields : Array[(String, String)] = [
      ("method", method),
      ("path", path),
      ("status", status.to_string()),
      ("client_ip", client_ip),
    ]

    if user_agent != "" {
      fields.push(("user_agent", user_agent))
    }
    if content_type != "" {
      fields.push(("content_type", content_type))
    }
    if config.include_latency {
      fields.push(("latency_ms", elapsed.to_string()))
    }

    // Add request_id if available
    match ctx.get_string("request_id") {
      Some(id) => fields.push(("request_id", id))
      None => ()
    }

    // Add static fields
    for sf in config.static_fields {
      let (k, v) = sf
      fields.push((k, v))
    }

    // Add app name and environment
    if global_config.app_name != "" {
      fields.push(("app", global_config.app_name))
    }
    if global_config.environment != "" {
      fields.push(("env", global_config.environment))
    }

    // Build message and log via moonbit-log
    let msg = method + " " + path + " -> " + status.to_string()

    let ml_level = if status >= 500 { @leppard/moonbit-log.Level::Error }
      else if status >= 400 { @leppard/moonbit-log.Level::Warn }
      else { @leppard/moonbit-log.Level::Info }
    @leppard/moonbit-log.g_log_with(ml_level, msg, fields)
  }
}

///| ——————————————————————————————————————————————————————————————————————
///  Metrics collector (basic)
///| ——————————————————————————————————————————————————————————————————————

///|
/// A simple in-memory metrics collector for request counts and latencies.
pub(all) struct MetricsCollector {
  /// Total requests by status code
  status_counts : Map[Int, Int64]
  /// Per-path request count
  path_counts : Map[String, Int64]
  /// Total request count
  mut total_requests : Int64
  /// Accumulated latency in ms
  mut total_latency_ms : Int64
  /// Min latency in ms
  mut min_latency_ms : Int64
  /// Max latency in ms
  mut max_latency_ms : Int64
}

///|
/// Create a new metrics collector.
pub fn MetricsCollector::new() -> MetricsCollector {
  {
    status_counts: Map([]),
    path_counts: Map([]),
    total_requests: 0L,
    total_latency_ms: 0L,
    min_latency_ms: 0L,
    max_latency_ms: 0L,
  }
}

///|
/// Record a request in the metrics collector.
pub fn MetricsCollector::record(
  self : MetricsCollector,
  status : Int,
  path : String,
  latency_ms : Int64,
) -> Unit {
  self.total_requests = self.total_requests + 1L
  self.total_latency_ms = self.total_latency_ms + latency_ms

  // Update status counts
  match self.status_counts.get(status) {
    Some(count) => self.status_counts.set(status, count + 1L)
    None => self.status_counts.set(status, 1L)
  }

  // Update path counts
  match self.path_counts.get(path) {
    Some(count) => self.path_counts.set(path, count + 1L)
    None => self.path_counts.set(path, 1L)
  }

  // Update min/max
  if self.min_latency_ms == 0L || latency_ms < self.min_latency_ms {
    self.min_latency_ms = latency_ms
  }
  if latency_ms > self.max_latency_ms {
    self.max_latency_ms = latency_ms
  }
}

///|
/// Export metrics as JSON for a `/metrics` endpoint.
pub fn MetricsCollector::to_json(self : MetricsCollector) -> Json {
  let status_map : Map[String, Json] = Map([])
  for code, count in self.status_counts {
    status_map.set(code.to_string(), Json::number(count.to_double()))
  }

  let top_paths : Map[String, Json] = Map([])
  for p, c in self.path_counts {
    top_paths.set(p, Json::number(c.to_double()))
  }

  Json::object({
    "total_requests": Json::number(self.total_requests.to_double()),
    "total_latency_ms": Json::number(self.total_latency_ms.to_double()),
    "min_latency_ms": Json::number(self.min_latency_ms.to_double()),
    "max_latency_ms": Json::number(self.max_latency_ms.to_double()),
    "avg_latency_ms": Json::number(
      if self.total_requests > 0L {
        (self.total_latency_ms / self.total_requests).to_double()
      } else {
        0.0
      },
    ),
    "status_codes": Json::object(status_map),
    "top_paths": Json::object(top_paths),
  })
}

///|
/// Metrics middleware — records request metrics into the provided collector.
///
/// ```
/// let metrics = MetricsCollector::new()
/// app.use(metrics_middleware(metrics))
/// app.get("/metrics", [fn(ctx) { ctx.json(200, metrics.to_json()) }])
/// ```
pub fn metrics_middleware(collector : MetricsCollector) -> Handler {
  async fn(ctx) {
    let start = @env.now()
    ctx.next()
    let elapsed = @env.now() - start
    collector.record(ctx.status_code, ctx.path(), elapsed.reinterpret_as_int64())
  }
}
