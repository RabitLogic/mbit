///|
/// Request ID middleware — generates a unique ID per request.
///
/// Also includes Timing middleware that adds an `X-Response-Time` header.

///|
/// Request ID middleware — generates a unique ID per request and adds it
/// to the response header.

pub fn request_id() -> Handler {
  fn(ctx) {
    let id = @async.now().to_string()
    ctx.set_header("X-Request-Id", id)
    ctx.set("request_id", Json::string(id))
    ctx.next()
  }
}

///|
/// Timing middleware — adds an `X-Response-Time` header with the request latency.
pub fn timing() -> Handler {
  fn(ctx) {
    let start = @async.now()
    ctx.next()
    let elapsed = @async.now() - start
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
  fn(ctx) {
    match ctx.header("Content-Length") {
      Some(cl) =>
        match (try? @string.parse_int64(cl)) {
          Ok(len) =>
            if len > max_bytes {
              ctx.abort_with_status(413, "Payload Too Large")
              return
            }
          Err(_) => ()
        }
      None => ()
    }
    ctx.next()
  }
}
