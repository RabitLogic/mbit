///|
/// Structured logger middleware — emits one JSON line per request, including
/// the `request_id` for distributed tracing. Pair it with `request_id()`.
///
/// Usage:
/// ```
/// app.use(request_id())
/// app.use(structured_logger())
/// ```

///|
/// Structured logger middleware. Logs a single JSON object per request after
/// the handler chain completes.
pub fn structured_logger() -> @core.Handler {
  async fn(ctx) {
    let start = @env.now()
    ctx.next()
    let end = @env.now()
    let latency_ms : Double = (end.to_double() - start.to_double()) / 1000.0
    let req_id = match ctx.get_string("request_id") {
      Some(id) => id
      None =>
        match ctx.headers.get("X-Request-Id") {
          Some(id) => id
          None => start.to_string()
        }
    }
    let mut line = "{\"level\":\"info\",\"msg\":\"request\","
    line = line + "\"ts\":" + start.to_string() + ","
    line = line + "\"request_id\":\"" + json_escape(req_id) + "\","
    line = line + "\"method\":\"" + json_escape(ctx.http_method()) + "\","
    line = line + "\"path\":\"" + json_escape(ctx.path()) + "\","
    line = line + "\"status\":" + ctx.status_code.to_string() + ","
    line = line + "\"latency_ms\":" + latency_ms.to_string() + ","
    line = line + "\"client_ip\":\"" + json_escape(ctx.client_ip()) + "\","
    line = line + "\"size\":" + ctx.size.to_string() + "}"
    println(line)
  }
}

///|
/// Escape a string for safe inclusion in a JSON string literal.
fn json_escape(s : String) -> String {
  s
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
    .replace_all(old="\n", new="\\n")
    .replace_all(old="\r", new="\\r")
    .replace_all(old="\t", new="\\t")
}
