///|
/// Request ID middleware — generates a unique ID per request.
///
/// Also includes Timing middleware that adds an `X-Response-Time` header.

///|
/// Request ID middleware — generates a unique ID per request and adds it
/// to the response header.

pub fn request_id() -> Handler {
  async fn(ctx) {
    let id = @env.now().to_string()
    ctx.set_header("X-Request-Id", id)
    ctx.set("request_id", Json::string(id))
    ctx.next()
  }
}

///|
/// Timing middleware — adds an `X-Response-Time` header with the request latency.
pub fn timing() -> Handler {
  async fn(ctx) {
    let start = @env.now()
    ctx.next()
    let elapsed = @env.now() - start
    ctx.set_header("X-Response-Time", "\{elapsed}ms")
  }
}

///|
/// Body size limiter middleware — aborts with 413 if Content-Length exceeds limit.
///
/// Usage:
/// ```
/// app.use(body_size_limit(1024 * 1024))  // 1 MB
/// ```
pub fn body_size_limit(max_bytes : Int64) -> Handler {
  async fn(ctx) {
    match ctx.header("Content-Length") {
      Some(cl) =>
        try {
          let len = @string.parse_int64(cl)
          if len > max_bytes {
            ctx.abort_with_status(413, "Payload Too Large")
            return
          }
        } catch {
          _ => ()
        }
      None => ()
    }
    ctx.next()
  }
}
