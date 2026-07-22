///|
/// Logger middleware — logs each request with method, path, status, and latency.
///
/// Logs via the structured logging system (moonbit-log), respecting
/// configured log levels and formats.
///
/// For more advanced logging (JSON, fields, levels), see `structured_logger()`.
///
/// Usage:
/// ```
/// app.use(logger())
/// ```

pub fn logger() -> Handler {
  async fn(ctx) {
    let start = @env.now()
    // Run the rest of the chain
    ctx.next()
    // After the chain completes
    let elapsed = @env.now() - start
    let status = ctx.status_code
    let meth = ctx.http_method()
    let path = ctx.path()
    let client_ip = ctx.client_ip()
    let fields = [
      ("method", meth),
      ("path", path),
      ("status", status.to_string()),
      ("latency_ms", elapsed.to_string()),
      ("client_ip", client_ip),
    ]
    if status >= 500 {
      Logger::error(meth + " " + path, fields=fields)
    } else if status >= 400 {
      Logger::warn(meth + " " + path, fields=fields)
    } else {
      Logger::info(meth + " " + path, fields=fields)
    }
  }
}
