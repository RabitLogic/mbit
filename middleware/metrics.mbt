///|
/// Metrics middleware — exposes a Prometheus-format `/metrics` endpoint and
/// records request counters, status codes, an in-flight gauge and a latency
/// histogram. mbit runs on a single-threaded event loop, so the store needs
/// no locking.
///
/// Usage:
/// ```
/// app.use(metrics())
/// // then scrape http://host:port/metrics with Prometheus
/// ```

///|
/// Latency histogram bucket upper bounds (seconds); `+Inf` is implicit.
let latency_buckets : Array[Double] = [
  0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0,
]

///|
/// MetricsStore holds all counters and histogram data.
pub(all) struct MetricsStore {
  /// Total completed requests
  mut total : Int64
  /// Requests grouped by HTTP method
  mut by_method : Map[String, Int64]
  /// Requests grouped by response status code
  mut by_status : Map[String, Int64]
  /// Requests that ended with a 5xx status
  mut errors : Int64
  /// Requests currently being processed
  mut in_flight : Int64
  /// Latency histogram counts keyed by bucket index
  mut latency_counts : Map[Int, Int64]
  /// Sum of request durations in seconds
  mut latency_sum : Double
  /// Server start time (ms since epoch)
  start_time : UInt64
}

///|
/// Create a fresh metrics store.
pub fn MetricsStore::new() -> MetricsStore {
  {
    total: 0L,
    by_method: Map([]),
    by_status: Map([]),
    errors: 0L,
    in_flight: 0L,
    latency_counts: Map([]),
    latency_sum: 0.0,
    start_time: @env.now(),
  }
}

///|
let metrics_store : MetricsStore = MetricsStore::new()

///|
/// Record a completed request.
pub fn MetricsStore::observe(
  self : MetricsStore,
  method : String,
  status : Int,
  duration_sec : Double,
) -> Unit {
  self.total = self.total + 1L
  let mcount = match self.by_method.get(method) {
    Some(v) => v
    None => 0L
  }
  self.by_method.set(method, mcount + 1L)
  let skey = status.to_string()
  let scount = match self.by_status.get(skey) {
    Some(v) => v
    None => 0L
  }
  self.by_status.set(skey, scount + 1L)
  if status >= 500 {
    self.errors = self.errors + 1L
  }
  self.latency_sum = self.latency_sum + duration_sec
  let mut idx = latency_buckets.length()
  for i in 0 ..< latency_buckets.length() {
    if duration_sec <= latency_buckets[i] {
      idx = i
      break
    }
  }
  let lcount = match self.latency_counts.get(idx) {
    Some(v) => v
    None => 0L
  }
  self.latency_counts.set(idx, lcount + 1L)
}

///|
/// Render the metrics in Prometheus text exposition format.
pub fn render_metrics() -> String {
  let mut out = "# HELP mbit_http_requests_total Total HTTP requests processed\n"
  out = out + "# TYPE mbit_http_requests_total counter\n"
  for k, v in metrics_store.by_method {
    out = out + "mbit_http_requests_total{method=\"" + k + "\"} " + v.to_string() + "\n"
  }
  out = out + "# HELP mbit_http_requests_by_status Total HTTP requests by status code\n"
  out = out + "# TYPE mbit_http_requests_by_status counter\n"
  for k, v in metrics_store.by_status {
    out = out + "mbit_http_requests_by_status{status=\"" + k + "\"} " + v.to_string() + "\n"
  }
  out = out + "# HELP mbit_http_errors_total Total 5xx responses\n"
  out = out + "# TYPE mbit_http_errors_total counter\n"
  out = out + "mbit_http_errors_total " + metrics_store.errors.to_string() + "\n"
  out = out + "# HELP mbit_http_requests_in_flight Requests currently in flight\n"
  out = out + "# TYPE mbit_http_requests_in_flight gauge\n"
  out = out + "mbit_http_requests_in_flight " + metrics_store.in_flight.to_string() + "\n"
  out = out + "# HELP mbit_http_request_duration_seconds Request latency in seconds\n"
  out = out + "# TYPE mbit_http_request_duration_seconds histogram\n"
  let mut cumulative : Int64 = 0L
  for i in 0 ..< latency_buckets.length() {
    let c = match metrics_store.latency_counts.get(i) {
      Some(v) => v
      None => 0L
    }
    cumulative = cumulative + c
    let le = latency_buckets[i].to_string()
    out = out + "mbit_http_request_duration_seconds_bucket{le=\"" + le + "\"} " + cumulative.to_string() + "\n"
  }
  out = out + "mbit_http_request_duration_seconds_bucket{le=\"+Inf\"} " + metrics_store.total.to_string() + "\n"
  out = out + "mbit_http_request_duration_seconds_sum " + metrics_store.latency_sum.to_string() + "\n"
  out = out + "mbit_http_request_duration_seconds_count " + metrics_store.total.to_string() + "\n"
  let uptime : UInt64 = @env.now() - metrics_store.start_time
  out = out + "# HELP mbit_http_server_uptime_seconds Server uptime in seconds\n"
  out = out + "# TYPE mbit_http_server_uptime_seconds gauge\n"
  out = out + "mbit_http_server_uptime_seconds " + (uptime.to_double() / 1000.0).to_string() + "\n"
  out
}

///|
/// Metrics middleware. Intercepts `/metrics` and serves the Prometheus text
/// format; for all other requests it records counters and latency.
pub fn metrics() -> @core.Handler {
  async fn(ctx) {
    if ctx.path() == "/metrics" {
      ctx.set_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
      ctx.string(200, render_metrics())
      return
    }
    metrics_store.in_flight = metrics_store.in_flight + 1L
    let start = @env.now()
    ctx.next()
    let end = @env.now()
    metrics_store.in_flight = metrics_store.in_flight - 1L
    let dur : Double = end.to_double() - start.to_double()
    metrics_store.observe(ctx.http_method(), ctx.status_code, dur / 1000.0)
  }
}
